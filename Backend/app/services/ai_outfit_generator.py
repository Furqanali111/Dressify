import json
import logging
from pathlib import Path

from openai import OpenAI, APIConnectionError, APIStatusError, APITimeoutError

from app.config import settings

logger = logging.getLogger(__name__)

_PROMPT_TEMPLATE = (
    Path(__file__).parent.parent / "prompts" / "outfit_generation.txt"
).read_text(encoding="utf-8")


def generate_outfit(
    wardrobe_details: str,
    occasion: str,
    weather: str | None,
    seed_item: str | None,
    style_profile: str | None = None,
) -> list[str]:
    """Return a list of string UUIDs chosen by the AI stylist.

    Raises RuntimeError on any failure so the router can surface a 503.
    """
    if settings.OPENAI_API_KEY:
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        model = settings.OPENAI_API_MODEL
    else:
        client = OpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = settings.OLLAMA_TEXT_MODEL

    style_line = f"    - User Style Profile: {style_profile}\n" if style_profile else ""
    seed_line  = f"    - Must Include This Item: {seed_item}\n" if seed_item else ""

    prompt = _PROMPT_TEMPLATE.format(
        occasion=occasion,
        weather=weather or "Unknown",
        seed_line=seed_line,
        style_line=style_line,
        wardrobe=wardrobe_details,
    )

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
            temperature=0.3,
        )
        content = response.choices[0].message.content
        data = json.loads(content)
        ids = data.get("item_ids", [])
        if not isinstance(ids, list):
            raise ValueError(f"Unexpected 'item_ids' type: {type(ids)}")
        return ids
    except (APIConnectionError, APITimeoutError) as e:
        logger.error(f"AI outfit generator network error ({model}): {e}")
        raise RuntimeError("AI service is unreachable — please try again shortly")
    except APIStatusError as e:
        logger.error(f"AI outfit generator API error ({model}) status={e.status_code}: {e}")
        raise RuntimeError("AI service returned an error — please try again shortly")
    except (json.JSONDecodeError, ValueError) as e:
        logger.error(f"AI outfit generator returned unparseable response ({model}): {e}")
        raise RuntimeError("AI returned an unrecognisable response — please try again")
    except Exception as e:
        logger.error(f"AI outfit generator unexpected failure ({model}): {e}", exc_info=True)
        raise RuntimeError("Outfit generation failed unexpectedly")
