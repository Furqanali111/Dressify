using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Animated upload/processing progress bar.
    /// Inspector setup:
    ///   - TrackImage: Image (full width, light gray)
    ///   - FillImage: Image with fillMethod = Horizontal, fillOrigin = Left (primary color)
    ///   - PercentLabel: TextMeshProUGUI (optional, shows "45%")
    /// </summary>
    public class ProgressBar : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Image           fillImage;
        [SerializeField] private TextMeshProUGUI percentLabel;

        [Header("Settings")]
        [SerializeField] private bool showLabel = true;

        private float     _targetProgress;
        private Coroutine _animRoutine;

        private void Awake()
        {
            if (fillImage != null)
            {
                fillImage.type       = Image.Type.Filled;
                fillImage.fillMethod = Image.FillMethod.Horizontal;
                fillImage.fillAmount = 0f;
                fillImage.color      = DesignSystem.Instance.GetPrimary();
            }
            UpdateLabel(0f);
        }

        // ── Public API ────────────────────────────────────────────────────────────

        /// <summary>Animate progress to value (0–1).</summary>
        public void SetProgress(float value)
        {
            _targetProgress = Mathf.Clamp01(value);
            if (_animRoutine != null) StopCoroutine(_animRoutine);
            _animRoutine = StartCoroutine(AnimateToTarget());
        }

        /// <summary>Instantly jump to value (no animation).</summary>
        public void SetProgressInstant(float value)
        {
            if (_animRoutine != null) { StopCoroutine(_animRoutine); _animRoutine = null; }
            _targetProgress = Mathf.Clamp01(value);
            if (fillImage != null) fillImage.fillAmount = _targetProgress;
            UpdateLabel(_targetProgress);
        }

        public void Reset() => SetProgressInstant(0f);

        // ── Internals ─────────────────────────────────────────────────────────────

        private IEnumerator AnimateToTarget()
        {
            if (fillImage == null) yield break;
            float from    = fillImage.fillAmount;
            float to      = _targetProgress;
            float dur     = 0.25f;
            float elapsed = 0f;

            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                float val = Mathf.Lerp(from, to, TweenHelper.EaseInOut(Mathf.Clamp01(elapsed / dur)));
                fillImage.fillAmount = val;
                UpdateLabel(val);
                yield return null;
            }
            fillImage.fillAmount = to;
            UpdateLabel(to);
        }

        private void UpdateLabel(float val)
        {
            if (!showLabel || percentLabel == null) return;
            percentLabel.text = $"{Mathf.RoundToInt(val * 100)}%";
        }
    }
}
