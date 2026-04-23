using UnityEngine;
using UnityEngine.UI;

namespace Dressify.Utils
{
    /// <summary>
    /// Draggable handle for the clothing overlay in Try-On Preview.
    /// Attach to corner handle GameObjects around the clothing RectTransform.
    /// Handles both drag (reposition) and pinch-to-zoom (resize).
    ///
    /// Inspector:
    ///   - ClothingRect: the RectTransform of the clothing overlay to control
    /// </summary>
    public class OverlayDragHandle : MonoBehaviour,
        UnityEngine.EventSystems.IDragHandler,
        UnityEngine.EventSystems.IBeginDragHandler,
        UnityEngine.EventSystems.IEndDragHandler
    {
        [SerializeField] private RectTransform clothingRect;

        private Vector2 _startPointerPos;
        private Vector2 _startAnchoredPos;

        public void OnBeginDrag(UnityEngine.EventSystems.PointerEventData e)
        {
            _startPointerPos   = e.position;
            _startAnchoredPos  = clothingRect != null ? clothingRect.anchoredPosition : Vector2.zero;
        }

        public void OnDrag(UnityEngine.EventSystems.PointerEventData e)
        {
            if (clothingRect == null) return;
            Vector2 delta = e.position - _startPointerPos;
            clothingRect.anchoredPosition = _startAnchoredPos + delta;
        }

        public void OnEndDrag(UnityEngine.EventSystems.PointerEventData e) { }
    }

    /// <summary>
    /// Handles two-finger pinch-to-scale and drag on the clothing overlay.
    /// Attach to the transparent overlay region of the PreviewCanvas.
    /// </summary>
    public class PinchToScale : MonoBehaviour
    {
        [SerializeField] private RectTransform clothingRect;
        [SerializeField] private float         minScale = 0.3f;
        [SerializeField] private float         maxScale = 3.0f;

        private float   _startDist;
        private Vector3 _startScale;

        private void Update()
        {
            if (Input.touchCount != 2 || clothingRect == null) return;

            var t0 = Input.GetTouch(0);
            var t1 = Input.GetTouch(1);

            if (t0.phase == TouchPhase.Began || t1.phase == TouchPhase.Began)
            {
                _startDist  = Vector2.Distance(t0.position, t1.position);
                _startScale = clothingRect.localScale;
            }
            else if (t0.phase == TouchPhase.Moved || t1.phase == TouchPhase.Moved)
            {
                float currentDist = Vector2.Distance(t0.position, t1.position);
                if (_startDist <= 0f) return;

                float factor = currentDist / _startDist;
                float newScale = Mathf.Clamp(_startScale.x * factor, minScale, maxScale);
                clothingRect.localScale = Vector3.one * newScale;
            }
        }
    }
}
