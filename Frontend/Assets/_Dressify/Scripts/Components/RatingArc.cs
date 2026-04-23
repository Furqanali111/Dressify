using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Circular rating arc badge with animated fill.
    /// Used in AI Feedback screen.
    /// Inspector setup:
    ///   - ArcImage: Image (radial fill type, 360° circle, primary color)
    ///   - TrackImage: Image (radial fill, full 1.0, gray)
    ///   - ScoreLabel: TextMeshProUGUI (e.g. "8.5")
    ///   - MaxLabel: TextMeshProUGUI (e.g. "/ 10")
    /// </summary>
    public class RatingArc : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Image           arcImage;
        [SerializeField] private TextMeshProUGUI scoreLabel;
        [SerializeField] private TextMeshProUGUI maxLabel;

        [Header("Colors")]
        [SerializeField] private Color goodColor  = new Color(0.133f, 0.788f, 0.478f);  // green ≥7
        [SerializeField] private Color midColor   = new Color(1.000f, 0.757f, 0.027f);  // amber 4–6
        [SerializeField] private Color badColor   = new Color(1.000f, 0.361f, 0.361f);  // red <4

        private Coroutine _animRoutine;

        private void Awake()
        {
            if (arcImage != null)
            {
                arcImage.type       = Image.Type.Filled;
                arcImage.fillMethod = Image.FillMethod.Radial360;
                arcImage.fillOrigin = (int)Image.Origin360.Top;
                arcImage.fillAmount = 0f;
            }
            if (maxLabel != null) maxLabel.text = "/ 10";
        }

        // ── Public API ────────────────────────────────────────────────────────────

        /// <summary>Animate arc from 0 to score (0–10) over 600ms ease-out.</summary>
        public void SetScore(float score)
        {
            float clamped = Mathf.Clamp(score, 0f, 10f);
            float fill    = clamped / 10f;
            Color arcColor = clamped >= 7f ? goodColor : clamped >= 4f ? midColor : badColor;

            if (arcImage != null) arcImage.color = arcColor;
            if (scoreLabel != null) scoreLabel.text = clamped.ToString("F1");

            if (_animRoutine != null) StopCoroutine(_animRoutine);
            _animRoutine = StartCoroutine(TweenHelper.ArcFill(arcImage, fill, 0.6f));
        }

        /// <summary>Show loading state (spinner-style pulsing arc).</summary>
        public void SetLoading(bool loading)
        {
            if (loading)
            {
                if (arcImage != null) arcImage.fillAmount = 0.25f;
                if (_animRoutine != null) StopCoroutine(_animRoutine);
                _animRoutine = StartCoroutine(SpinArc());
            }
            else
            {
                if (_animRoutine != null)
                {
                    StopCoroutine(_animRoutine);
                    _animRoutine = null;
                }
            }
        }

        private IEnumerator SpinArc()
        {
            while (true)
            {
                arcImage.transform.Rotate(0, 0, -180f * Time.deltaTime);
                yield return null;
            }
        }
    }
}
