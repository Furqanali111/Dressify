using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;

namespace Dressify.Core
{
    /// <summary>
    /// Lightweight coroutine-based tween helpers.
    /// Covers every animation listed in the spec without requiring DOTween.
    /// If DOTween is imported, you can replace these with DOTween equivalents.
    /// </summary>
    public static class TweenHelper
    {
        // ── Easing ───────────────────────────────────────────────────────────────

        public static float EaseInOut(float t)   => t < 0.5f ? 2f * t * t : -1f + (4f - 2f * t) * t;
        public static float EaseOut(float t)     => 1f - (1f - t) * (1f - t);
        public static float EaseOutBack(float t) { float c1 = 1.70158f; float c3 = c1 + 1f; return 1f + c3 * Mathf.Pow(t - 1f, 3f) + c1 * Mathf.Pow(t - 1f, 2f); }
        public static float Spring(float t)      => Mathf.Sin(t * Mathf.PI * (0.2f + 2.5f * t * t * t)) * Mathf.Pow(1f - t, 2.2f) + t;

        // ── Scale ─────────────────────────────────────────────────────────────────

        /// <summary>Button press: scale to 0.97 then back.</summary>
        public static IEnumerator ButtonPress(MonoBehaviour host, Transform target, Action onComplete = null)
        {
            yield return host.StartCoroutine(ScaleTo(target, Vector3.one * 0.97f, 0.10f, EaseOut));
            yield return host.StartCoroutine(ScaleTo(target, Vector3.one,        0.10f, EaseOut));
            onComplete?.Invoke();
        }

        /// <summary>Avatar card select: scale to 1.04.</summary>
        public static IEnumerator CardSelect(MonoBehaviour host, Transform target)
        {
            yield return host.StartCoroutine(ScaleTo(target, Vector3.one * 1.04f, 0.18f, EaseOut));
        }

        /// <summary>Avatar card deselect: scale back to 1.0.</summary>
        public static IEnumerator CardDeselect(MonoBehaviour host, Transform target)
        {
            yield return host.StartCoroutine(ScaleTo(target, Vector3.one, 0.18f, EaseOut));
        }

        public static IEnumerator ScaleTo(Transform t, Vector3 target, float dur, Func<float, float> ease)
        {
            Vector3 start  = t.localScale;
            float elapsed  = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                float f = ease(Mathf.Clamp01(elapsed / dur));
                t.localScale = Vector3.LerpUnclamped(start, target, f);
                yield return null;
            }
            t.localScale = target;
        }

        // ── Alpha / Fade ─────────────────────────────────────────────────────────

        public static IEnumerator FadeTo(CanvasGroup cg, float target, float dur, Func<float, float> ease = null)
        {
            ease ??= EaseOut;
            float start   = cg.alpha;
            float elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                cg.alpha = Mathf.LerpUnclamped(start, target, ease(Mathf.Clamp01(elapsed / dur)));
                yield return null;
            }
            cg.alpha = target;
        }

        public static IEnumerator FadeGraphic(Graphic g, float target, float dur)
        {
            Color start = g.color;
            Color end   = new Color(start.r, start.g, start.b, target);
            float elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                g.color = Color.Lerp(start, end, EaseOut(Mathf.Clamp01(elapsed / dur)));
                yield return null;
            }
            g.color = end;
        }

        // ── Position ─────────────────────────────────────────────────────────────

        public static IEnumerator SlideY(RectTransform rt, float fromY, float toY, float dur, Func<float, float> ease = null)
        {
            ease ??= EaseOut;
            float elapsed = 0f;
            Vector2 pos   = rt.anchoredPosition;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                pos.y = Mathf.LerpUnclamped(fromY, toY, ease(Mathf.Clamp01(elapsed / dur)));
                rt.anchoredPosition = pos;
                yield return null;
            }
            pos.y = toY;
            rt.anchoredPosition = pos;
        }

        /// <summary>Bottom sheet spring open.</summary>
        public static IEnumerator SpringUp(MonoBehaviour host, RectTransform rt, float fromY, float toY, float dur = 0.35f)
        {
            yield return host.StartCoroutine(SlideY(rt, fromY, toY, dur, Spring));
        }

        // ── Arc / Radial fill ────────────────────────────────────────────────────

        public static IEnumerator ArcFill(Image arcImage, float targetFill, float dur = 0.6f)
        {
            float start   = arcImage.fillAmount;
            float elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                arcImage.fillAmount = Mathf.LerpUnclamped(start, targetFill, EaseOut(Mathf.Clamp01(elapsed / dur)));
                yield return null;
            }
            arcImage.fillAmount = targetFill;
        }

        // ── Shimmer ──────────────────────────────────────────────────────────────

        public static IEnumerator ShimmerLoop(Graphic g, float duration = 1.2f)
        {
            Color baseColor = g.color;
            Color brightColor = Color.Lerp(baseColor, Color.white, 0.35f);
            while (true)
            {
                // Ping-pong alpha between base and bright
                float t = (Mathf.Sin(Time.time * (Mathf.PI * 2f / duration)) + 1f) / 2f;
                g.color = Color.Lerp(baseColor, brightColor, t);
                yield return null;
            }
        }

        // ── Logo launch animation ─────────────────────────────────────────────────

        public static IEnumerator LogoEntrance(MonoBehaviour host, RectTransform logo, CanvasGroup cg)
        {
            // Spec: fade-in + scale-up 400ms
            logo.localScale = Vector3.one * 0.80f;
            cg.alpha = 0f;
            float dur = 0.4f;
            float elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                float t = EaseOut(Mathf.Clamp01(elapsed / dur));
                logo.localScale = Vector3.LerpUnclamped(Vector3.one * 0.80f, Vector3.one, t);
                cg.alpha = t;
                yield return null;
            }
            logo.localScale = Vector3.one;
            cg.alpha = 1f;
        }

        // ── Progress bar ─────────────────────────────────────────────────────────

        public static IEnumerator AnimateProgress(Image fillImage, float from, float to, float dur)
        {
            float elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                fillImage.fillAmount = Mathf.Lerp(from, to, EaseInOut(Mathf.Clamp01(elapsed / dur)));
                yield return null;
            }
            fillImage.fillAmount = to;
        }

        // ── Toast ────────────────────────────────────────────────────────────────

        public static IEnumerator ToastAppear(MonoBehaviour host, RectTransform rt, CanvasGroup cg, float visibleDuration = 3f)
        {
            // Slide up in 200ms
            float offY = rt.anchoredPosition.y - 60f;
            float onY  = rt.anchoredPosition.y;
            rt.anchoredPosition = new Vector2(rt.anchoredPosition.x, offY);
            cg.alpha = 0f;
            yield return host.StartCoroutine(SlideY(rt, offY, onY, 0.2f, EaseOut));
            yield return host.StartCoroutine(FadeTo(cg, 1f, 0.15f));
            yield return new WaitForSeconds(visibleDuration);
            // Slide down out 200ms
            yield return host.StartCoroutine(FadeTo(cg, 0f, 0.2f));
            yield return host.StartCoroutine(SlideY(rt, onY, offY, 0.2f, EaseOut));
        }
    }
}
