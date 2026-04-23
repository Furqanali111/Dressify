using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Circular icon button (44dp normal / 56dp FAB).
    /// Inspector setup:
    ///   - Background: Image (circle sprite, white or primary color)
    ///   - Icon: Image (24dp, centered)
    ///   - RippleOverlay: Image (white, alpha 0, circle sprite) — for ripple effect
    /// </summary>
    [RequireComponent(typeof(Button))]
    public class IconButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
    {
        [Header("References")]
        [SerializeField] private Image iconImage;
        [SerializeField] private Image rippleOverlay;

        [Header("Settings")]
        [SerializeField] private Sprite icon;
        [SerializeField] private bool   isFab;   // 56dp FAB variant

        public event Action OnClick;

        private Button _button;

        private void Awake()
        {
            _button = GetComponent<Button>();
            _button.onClick.AddListener(() => OnClick?.Invoke());
            if (icon != null && iconImage != null)
                iconImage.sprite = icon;
        }

        public void OnPointerDown(PointerEventData e) =>
            StartCoroutine(Ripple());

        public void OnPointerUp(PointerEventData e)
        {
            // handled by ripple coroutine
        }

        public void SetIcon(Sprite s)
        {
            icon = s;
            if (iconImage != null) iconImage.sprite = s;
        }

        public void SetInteractable(bool v) => _button.interactable = v;

        private IEnumerator Ripple()
        {
            if (rippleOverlay == null) yield break;
            rippleOverlay.gameObject.SetActive(true);

            // Scale from 0 to 1, alpha 0.3 → 0
            rippleOverlay.transform.localScale = Vector3.zero;
            var c = rippleOverlay.color;
            c.a = 0.3f;
            rippleOverlay.color = c;

            float dur = 0.3f, elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                float t = TweenHelper.EaseOut(Mathf.Clamp01(elapsed / dur));
                rippleOverlay.transform.localScale = Vector3.one * t;
                c.a = Mathf.Lerp(0.3f, 0f, t);
                rippleOverlay.color = c;
                yield return null;
            }
            rippleOverlay.gameObject.SetActive(false);
        }
    }
}
