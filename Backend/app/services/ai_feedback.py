"""AI Feedback Service — Vision-powered outfit analysis.

Strategy:
  1. Vision multimodal input: garment images are fetched from Supabase Storage,
     base64-encoded, and sent directly to the LLM as image_url content blocks.
     This gives the model actual visual context rather than relying on text descriptions.
  2. Rotation Sampling for wardrobe context: instead of injecting the user's
     entire wardrobe (which blows token limits), we sample 15 underused items
     the user has not worn recently. This keeps the prompt lean while actively
     encouraging wardrobe rotation.
"""

import base64
import json
import logging
from typing import Optional

from openai import OpenAI, APIConnectionError, APIStatusError, APITimeoutError
from app.config import settings
from app.services.storage import download_file

logger = logging.getLogger(__name__)

# Maximum number of outfit item images to send to the vision model
_MAX_VISION_IMAGES = 4
# Wardrobe rotation sample cap (text-only, sent as pairing suggestions)
_MAX_WARDROBE_SAMPLE = 15


def _image_to_data_url(image_bytes: bytes) -> str:
    """Convert raw image bytes to a base64 data URL for vision API."""
    b64 = base64.b64encode(image_bytes).decode("utf-8")
    return f"data:image/jpeg;base64,{b64}"


def get_feedback_for_outfit(
    outfit_details: str,
    occasion: Optional[str],
    wardrobe_sample: list[str],
    weather: Optional[str] = None,
    outfit_image_paths: Optional[list[str]] = None,
) -> dict:
    """Return parsed feedback dict from the AI vision stylist.

    Args:
        outfit_details:     Textual description of the current outfit.
        occasion:           Optional occasion context (e.g. "casual", "formal").
        wardrobe_sample:    Curated list of ≤15 underused wardrobe item descriptions
                            for rotation pairing suggestions.
        weather:            Optional current weather string.
        outfit_image_paths: Optional list of Supabase processed_image_path values
                            for the items in the outfit. If provided, the images are
                            downloaded and sent to the vision model.

    Raises:
        RuntimeError: user-facing message on any failure.
    """
    use_openai = bool(settings.OPENAI_API_KEY)
    if use_openai:
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        model = settings.OPENAI_API_MODEL
    else:
        client = OpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = settings.OLLAMA_VISION_MODEL

    # ── Build vision image blocks ─────────────────────────────────────────────
    vision_blocks: list[dict] = []
    if outfit_image_paths:
        for path in outfit_image_paths[:_MAX_VISION_IMAGES]:
            try:
                img_bytes = download_file(settings.CLOTHING_BUCKET, path)
                if img_bytes:
                    data_url = _image_to_data_url(img_bytes)
                    vision_blocks.append({
                        "type": "image_url",
                        "image_url": {"url": data_url, "detail": "low"},
                    })
            except Exception as e:
                logger.warning("Could not fetch outfit image '%s' for vision: %s", path, e)

    # ── Build the text prompt ─────────────────────────────────────────────────
    wardrobe_context = (
        "\n".join(f"  - {item}" for item in wardrobe_sample)
        if wardrobe_sample
        else "  (No additional wardrobe data available)"
    )

    text_prompt = f"""You are an expert AI fashion stylist with vision capabilities.
{"You are viewing the actual garment images above. Use them to give precise, visually-grounded advice." if vision_blocks else ""}

Respond ONLY with a raw JSON object matching this exact schema — no markdown, no explanation:
{{
  "score": 8.5,
  "verdict": "A concise one-sentence summary of the overall outfit look.",
  "suggestions": [
    {{
      "category": "color",
      "title": "Short title (≤5 words)",
      "detail": "Detailed actionable advice. Reference specific garment colours you can see. Suggest complementary items from the wardrobe list if applicable."
    }},
    {{
      "category": "balance",
      "title": "Short title",
      "detail": "Advice on silhouette, proportion, and volume balance."
    }},
    {{
      "category": "occasion",
      "title": "Short title",
      "detail": "How well the outfit fits the occasion and weather. Suggest adjustments if needed."
    }},
    {{
      "category": "accessories",
      "title": "Short title",
      "detail": "Accessory recommendations — shoes, bags, jewellery, watches."
    }}
  ]
}}

Context:
- Outfit: {outfit_details}
- Occasion: {occasion or 'General / everyday wear'}
- Weather: {weather or 'Unknown'}
- Wardrobe items available for pairing suggestions (underused — help the user rotate their wardrobe):
{wardrobe_context}

Rules:
1. score must be a float between 0.0 and 10.0.
2. Provide EXACTLY 4 suggestions, one per category: color, balance, occasion, accessories.
3. If garment images are provided, base your colour and balance feedback on what you actually see.
4. Mention specific items from the wardrobe list above when making pairing suggestions.
5. Keep each 'detail' field between 30 and 120 words.
"""

    # ── Assemble the message content ──────────────────────────────────────────
    user_content: list[dict] = []
    # Images first (vision models attend to images before text)
    user_content.extend(vision_blocks)
    user_content.append({"type": "text", "text": text_prompt})

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are an expert fashion stylist with computer vision capabilities. "
                        "You analyse outfit images and give structured JSON feedback. "
                        "You ONLY respond with raw JSON — no markdown, no commentary."
                    ),
                },
                {"role": "user", "content": user_content},
            ],
            # response_format JSON mode is only supported on text-only calls for Ollama;
            # for vision payloads we strip manually.
            **({"response_format": {"type": "json_object"}} if use_openai and not vision_blocks else {}),
            temperature=0.6,
            max_tokens=1024,
        )
        raw = response.choices[0].message.content or ""
        # Strip any accidental markdown code fences
        raw = raw.strip()
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        raw = raw.strip()

        result = json.loads(raw)
        for key in ("score", "verdict", "suggestions"):
            if key not in result:
                raise ValueError(f"AI response missing required key: '{key}'. Keys present: {list(result.keys())}")
        return result

    except (APIConnectionError, APITimeoutError) as e:
        logger.error("AI feedback network error (%s): %s", model, e)
        raise RuntimeError("AI service is unreachable — please try again shortly")
    except APIStatusError as e:
        logger.error("AI feedback API error (%s) status=%s: %s", model, e.status_code, e)
        raise RuntimeError("AI service returned an error — please try again shortly")
    except (json.JSONDecodeError, ValueError) as e:
        logger.error("AI feedback returned unparseable response (%s): %s", model, e)
        raise RuntimeError("AI returned an unrecognisable response — please try again")
    except Exception as e:
        logger.error("AI feedback unexpected failure (%s): %s", model, e, exc_info=True)
        raise RuntimeError("Feedback generation failed unexpectedly")
