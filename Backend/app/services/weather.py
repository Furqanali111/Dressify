import httpx
import logging

logger = logging.getLogger(__name__)

async def get_current_weather(lat: float, lon: float) -> str | None:
    """
    Fetch current weather from Open-Meteo for the given coordinates.
    Returns a formatted string like '72°F, Clear' or None if it fails.
    """
    try:
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true&temperature_unit=fahrenheit"
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=5.0)
            response.raise_for_status()
            data = response.json()
            
            weather = data.get("current_weather", {})
            temp = weather.get("temperature")
            # Basic WMO weather code mapping (simplified for prompt)
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
                
            return f"{temp}°F, {condition}"
            
    except httpx.HTTPError as e:
        logger.error(f"Weather API failed: {e}")
        return None
