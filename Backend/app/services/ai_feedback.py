import json
import logging
from openai import OpenAI, APIConnectionError, APIStatusError, APITimeoutError
from app.config import settings

logger = logging.getLogger(__name__)


def get_feedback_for_outfit(
    outfit_details: str,
    occasion: str | None,
    wardrobe_details: str,
    weather: str | None = None,
) -> dict:
    """Return parsed feedback dict from the AI stylist.

    Raises RuntimeError (with a user-facing message) on any failure.
    """
    if settings.OPENAI_API_KEY:
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        model = "gpt-4o-mini"
    else:
        client = OpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = "llama3.2"

    prompt = f"""
    You are an expert AI fashion stylist. The user is asking for feedback on an outfit.
    Provide your response strictly as a JSON object matching this schema:
    {{
        "score": 8.5, // float from 0 to 10
        "verdict": "A concise, one-line summary of the outfit.",
        "suggestions": [
            {{
                "category": "color", // must be one of: color, balance, occasion, accessories
                "title": "Short title",
                "detail": "A detailed explanation of the suggestion. If suggesting pairings, mention specific items from the user's wardrobe."
            }}
        ] // Provide exactly 4 suggestions, one for each category.
    }}

    Context:
    - Outfit details: {outfit_details}
    - Occasion (if specified): {occasion or 'General wear'}
    - Current Weather (if specified): {weather or 'Unknown'}
    - User's Wardrobe (for suggestions): {wardrobe_details}

    Important Instructions:
    - Take the 'Occasion' and 'Current Weather' into account when evaluating the outfit.
    - In your detailed suggestions (especially color and balance), explicitly recommend complementary colors.
    - Suggest specific items from the 'User's Wardrobe' that would go well with this outfit.
    """

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are an expert fashion stylist. You only respond with raw JSON."},
                {"role": "user", "content": prompt},
            ],
            response_format={"type": "json_object"},
            temperature=0.7,
        )
        content = response.choices[0].message.content
        result = json.loads(content)
        if "score" not in result or "verdict" not in result or "suggestions" not in result:
            raise ValueError(f"AI response missing required keys: {list(result.keys())}")
        return result
    except (APIConnectionError, APITimeoutError) as e:
        logger.error(f"AI feedback network error ({model}): {e}")
        raise RuntimeError("AI service is unreachable — please try again shortly")
    except APIStatusError as e:
        logger.error(f"AI feedback API error ({model}) status={e.status_code}: {e}")
        raise RuntimeError("AI service returned an error — please try again shortly")
    except (json.JSONDecodeError, ValueError) as e:
        logger.error(f"AI feedback returned unparseable response ({model}): {e}")
        raise RuntimeError("AI returned an unrecognisable response — please try again")
    except Exception as e:
        logger.error(f"AI feedback unexpected failure ({model}): {e}", exc_info=True)
        raise RuntimeError("Feedback generation failed unexpectedly")
