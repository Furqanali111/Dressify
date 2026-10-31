"""Shared OpenAI/Ollama client selection and utilities."""
import base64
from openai import OpenAI
from app.config import settings


def get_openai_client() -> tuple[OpenAI, str]:
    """Return (client, model) configured for OpenAI or Ollama based on settings."""
    if settings.OPENAI_API_KEY:
        return OpenAI(api_key=settings.OPENAI_API_KEY), settings.OPENAI_API_MODEL
    return OpenAI(base_url=settings.OLLAMA_BASE_URL, api_key="ollama"), settings.OLLAMA_VISION_MODEL


def image_to_data_url(image_bytes: bytes, mime: str = "image/jpeg") -> str:
    """Convert raw image bytes to a base64 data URL for vision APIs."""
    b64 = base64.b64encode(image_bytes).decode("utf-8")
    return f"data:{mime};base64,{b64}"
