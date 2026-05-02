"""Weather service with TTL caching and a reused httpx client.

Caches results per (rounded lat, rounded lon) for 15 minutes to avoid
fetching the Open-Meteo API on every AI request.
"""

import logging
import time
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

# ── Shared async client (connection pool reuse) ───────────────────────────────
_client: Optional[httpx.AsyncClient] = None


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(timeout=5.0)
    return _client


# ── Simple TTL cache: { (lat_r, lon_r): (result_str, expires_at) } ───────────
_CACHE_TTL_SECONDS = 900  # 15 minutes
_weather_cache: dict[tuple[float, float], tuple[Optional[str], float]] = {}


def _cache_key(lat: float, lon: float) -> tuple[float, float]:
    """Round coordinates to ~10 km precision for the cache key."""
    return round(lat, 1), round(lon, 1)


async def get_current_weather(lat: float, lon: float) -> Optional[str]:
    """Fetch current weather from Open-Meteo for the given coordinates.

    Returns a formatted string like '72°F, Clear' or None if it fails.
    Results are cached per (rounded lat, lon) for 15 minutes.
    """
    key = _cache_key(lat, lon)
    now = time.time()

    cached_value, expires_at = _weather_cache.get(key, (None, 0.0))
    if expires_at > now:
        logger.debug("Weather cache HIT for key %s", key)
        return cached_value

    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            f"&current_weather=true&temperature_unit=fahrenheit"
        )
        client = _get_client()
        response = await client.get(url)
        response.raise_for_status()
        data = response.json()

        weather = data.get("current_weather", {})
        temp = weather.get("temperature")
        code = weather.get("weathercode", 0)

        condition = "Clear"
        if code in [1, 2, 3]:
            condition = "Cloudy"
        elif code in [45, 48]:
            condition = "Foggy"
        elif code in [51, 53, 55, 61, 63, 65, 80, 81, 82]:
            condition = "Rainy"
        elif code in [71, 73, 75, 85, 86]:
            condition = "Snowy"
        elif code in [95, 96, 99]:
            condition = "Thunderstorm"

        result = f"{temp}°F, {condition}"
        _weather_cache[key] = (result, now + _CACHE_TTL_SECONDS)
        return result

    except httpx.HTTPError as e:
        logger.error("Weather API failed: %s", e)
        # Cache the failure briefly (60 s) to avoid hammering on repeated calls
        _weather_cache[key] = (None, now + 60)
        return None
