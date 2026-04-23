using System.Collections;
using UnityEngine;
using UnityEngine.UI;

namespace Dressify.Components
{
    /// <summary>
    /// Animated shimmer skeleton placeholder.
    /// Place over any UI area that is loading.
    /// Inspector setup:
    ///   - ShimmerImage: Image component to shimmer
    ///   - Optionally multiple shimmer images controlled at once
    /// </summary>
    public class LoadingSkeleton : MonoBehaviour
    {
        [SerializeField] private Image[] shimmerImages;

        [Header("Shimmer Settings")]
        [SerializeField] private Color  baseColor   = new Color(0.88f, 0.88f, 0.90f);
        [SerializeField] private Color  highlightColor = new Color(0.96f, 0.96f, 0.98f);
        [SerializeField] private float  speed       = 1.2f;   // seconds per cycle

        private Coroutine _shimmerRoutine;

        private void OnEnable()  => StartShimmer();
        private void OnDisable() => StopShimmer();

        public void StartShimmer()
        {
            StopShimmer();
            _shimmerRoutine = StartCoroutine(ShimmerRoutine());
        }

        public void StopShimmer()
        {
            if (_shimmerRoutine != null)
            {
                StopCoroutine(_shimmerRoutine);
                _shimmerRoutine = null;
            }
            // Reset to base color
            if (shimmerImages != null)
                foreach (var img in shimmerImages)
                    if (img != null) img.color = baseColor;
        }

        private IEnumerator ShimmerRoutine()
        {
            if (shimmerImages == null || shimmerImages.Length == 0) yield break;

            while (true)
            {
                float t = (Mathf.Sin(Time.time * (Mathf.PI * 2f / speed)) + 1f) / 2f;
                Color c = Color.Lerp(baseColor, highlightColor, t);
                foreach (var img in shimmerImages)
                    if (img != null) img.color = c;
                yield return null;
            }
        }

        public void Show() => gameObject.SetActive(true);
        public void Hide() => gameObject.SetActive(false);
    }
}
