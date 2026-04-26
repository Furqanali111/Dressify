import json
import logging
from openai import OpenAI, APIConnectionError, APIStatusError, APITimeoutError
from app.config import settings

logger = logging.getLogger(__name__)


def generate_outfit(
    wardrobe_details: str,
    occasion: str,
    weather: str | None,
    seed_item: str | None,
) -> list[str]:
    """Return a list of string UUIDs chosen by the AI stylist.

    Raises RuntimeError on any failure so the router can surface a 503.
    """
    if settings.OPENAI_API_KEY:
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        model = "gpt-4o-mini"
    else:
        client = OpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama")
        model = "llama3.2"

    prompt = f"""
    You are an AI fashion stylist. I will give you my wardrobe and I need you to build ONE complete outfit.
    Context:
    - Occasion: {occasion}
    - Current Weather: {weather or 'Unknown'}
    - Must Include This Item: {seed_item or 'None specified'}
    - My Wardrobe (ID: Name/Type): {wardrobe_details}

    Select a top, bottom, and shoes (and jacket if weather/occasion calls for it) from the wardrobe that form a cohesive outfit.
    Return strictly a JSON object with a single key 'item_ids' containing an array of the chosen UUID strings.
    Example: {{"item_ids": ["uuid-1", "uuid-2"]}}
    """

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
