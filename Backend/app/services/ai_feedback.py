import json
from openai import OpenAI
from app.config import settings
import logging

logger = logging.getLogger(__name__)

# Fallback response
FALLBACK_SUGGESTIONS = [
    {"category": "color", "title": "Great Color", "detail": "The colors match well."},
    {"category": "balance", "title": "Good Proportion", "detail": "The fit is nicely proportioned."},
    {"category": "occasion", "title": "Versatile", "detail": "Great for many occasions."},
    {"category": "trend", "title": "Trendy", "detail": "This is very on trend right now."}
]

def get_feedback_for_outfit(outfit_details: str, occasion: str | None, wardrobe_details: str, weather: str | None = None) -> dict:
    if settings.OPENAI_API_KEY:
        client = OpenAI(api_key=settings.OPENAI_API_KEY)
        model = "gpt-4o-mini"
    else:
        # Fallback to local Llama 3.2 via Ollama
        # OpenAI python client is fully compatible with Ollama's API
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
                "category": "color", // must be one of: color, balance, occasion, trend
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
    - Suggest specific items from the 'User's Wardrobe' that would go well with this outfit (e.g., "Swap the top with your [Wardrobe Item] for a better color match").
    """

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "You are an expert fashion stylist. You only respond with raw JSON."},
                {"role": "user", "content": prompt}
            ],
            response_format={"type": "json_object"},
            temperature=0.7,
        )
        
        content = response.choices[0].message.content
        result = json.loads(content)
        return result
    except Exception as e:
        logger.error(f"AI Feedback API failed using model {model}: {e}")
        return {
            "score": 7.5,
            "verdict": "Nice outfit! (AI fallback)",
            "suggestions": FALLBACK_SUGGESTIONS
        }
