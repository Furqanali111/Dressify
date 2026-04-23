using UnityEngine;
using UnityEngine.UI;

namespace Dressify.Utils
{
    /// <summary>
    /// Adjusts a RectTransform to respect the device safe area.
    /// Attach to any full-screen Canvas panel that needs to avoid
    /// notches, punch-holes, and gesture navigation bars.
    ///
    /// Inspector: set PanelRect to the panel to inset.
    /// </summary>
    [RequireComponent(typeof(RectTransform))]
    public class SafeAreaHandler : MonoBehaviour
    {
        private RectTransform _panel;
        private Rect          _lastSafeArea = Rect.zero;
        private Vector2       _lastScreenSize;

        private void Awake()
        {
            _panel = GetComponent<RectTransform>();
        }

        private void Update()
        {
            // Re-apply only when safe area changes (orientation, keyboard)
            var sa = Screen.safeArea;
            var screenSize = new Vector2(Screen.width, Screen.height);
            if (sa != _lastSafeArea || screenSize != _lastScreenSize)
            {
                _lastSafeArea   = sa;
                _lastScreenSize = screenSize;
                Apply(sa);
            }
        }

        private void Apply(Rect sa)
        {
            if (_panel == null) return;

            // Convert safe area to anchor min/max (0–1 range)
            var anchorMin = sa.position;
            var anchorMax = sa.position + sa.size;

            anchorMin.x /= Screen.width;
            anchorMin.y /= Screen.height;
            anchorMax.x /= Screen.width;
            anchorMax.y /= Screen.height;

            _panel.anchorMin = anchorMin;
            _panel.anchorMax = anchorMax;

            // Reset offsets so the panel exactly matches the safe area rect
            _panel.offsetMin = Vector2.zero;
            _panel.offsetMax = Vector2.zero;
        }
    }
}
