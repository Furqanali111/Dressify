import io
from rembg import remove
from PIL import Image
import logging

logger = logging.getLogger(__name__)

def remove_background(image_bytes: bytes) -> bytes:
    try:
        input_image = Image.open(io.BytesIO(image_bytes))
        output_image = remove(input_image)
        
        img_byte_arr = io.BytesIO()
        output_image.save(img_byte_arr, format='PNG')
        return img_byte_arr.getvalue()
    except Exception as e:
        logger.error(f"Background removal failed: {e}")
        raise e

def detect_type_and_anchors(image_bytes: bytes) -> tuple[str, dict, float]:
    # Placeholder for static anchor guesses and type detection
    # In Phase 1, we return 'top' and center-of-frame anchors statically
    anchors = {
        "shoulder": {"x": 0.5, "y": 0.2},
        "chest": {"x": 0.5, "y": 0.4},
        "waist": {"x": 0.5, "y": 0.8}
    }
    return "top", anchors, 0.8
