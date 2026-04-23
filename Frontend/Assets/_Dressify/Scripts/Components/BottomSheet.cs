using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Bottom sheet panel with drag handle, spring open/close, and scrim backdrop.
    /// Inspector setup:
    ///   - ScrimImage: full-screen Image (overlay color, alpha 0 when closed)
    ///   - SheetPanel: RectTransform anchored to bottom
    ///   - DragHandle: Image (40×4dp, gray, centered at top)
    ///   - CloseButton: Button on scrim (optional)
    /// </summary>
    public class BottomSheet : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private RectTransform sheetPanel;
        [SerializeField] private Image         scrim;
        [SerializeField] private Button        scrimButton;    // tap scrim to close
        [SerializeField] private CanvasGroup   sheetCanvasGroup;

        [Header("Settings")]
        [SerializeField] private float openHeightRatio = 0.75f;   // 75% screen height

        private float   _screenHeight;
        private float   _closedY;
        private float   _openY;
        private bool    _isOpen;
        private Coroutine _routine;

        public bool IsOpen => _isOpen;
        public event Action OnOpened;
        public event Action OnClosed;

        private void Awake()
        {
            _screenHeight = Screen.height;
            _closedY = -_screenHeight;
            _openY   = 0f;

            if (sheetPanel != null)
            {
                var sd = sheetPanel.sizeDelta;
                sd.y = _screenHeight * openHeightRatio;
                sheetPanel.sizeDelta = sd;
                sheetPanel.anchoredPosition = new Vector2(0f, _closedY);
            }

            if (scrim != null) scrim.color = Color.clear;
            if (scrimButton != null) scrimButton.onClick.AddListener(Close);

            gameObject.SetActive(false);
        }

        // ── Public API ────────────────────────────────────────────────────────────

        public void Open()
        {
            if (_isOpen) return;
            gameObject.SetActive(true);
            _isOpen = true;
            if (_routine != null) StopCoroutine(_routine);
            _routine = StartCoroutine(OpenRoutine());
        }

        public void Close()
        {
            if (!_isOpen) return;
            _isOpen = false;
            if (_routine != null) StopCoroutine(_routine);
            _routine = StartCoroutine(CloseRoutine());
        }

        // ── Internals ─────────────────────────────────────────────────────────────

        private IEnumerator OpenRoutine()
        {
            // Scrim fade in
            StartCoroutine(FadeScrim(0f, 0.55f, 0.3f));
            // Spring up
            float from = sheetPanel.anchoredPosition.y;
            yield return StartCoroutine(TweenHelper.SpringUp(this, sheetPanel, from, _openY, 0.35f));
            OnOpened?.Invoke();
        }

        private IEnumerator CloseRoutine()
        {
            // Scrim fade out
            StartCoroutine(FadeScrim(0.55f, 0f, 0.25f));
            // Slide down
            float from = sheetPanel.anchoredPosition.y;
            yield return StartCoroutine(TweenHelper.SlideY(sheetPanel, from, _closedY, 0.25f, TweenHelper.EaseOut));
            gameObject.SetActive(false);
            OnClosed?.Invoke();
        }

        private IEnumerator FadeScrim(float from, float to, float dur)
        {
            if (scrim == null) yield break;
            float elapsed = 0f;
            Color c = scrim.color;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                c.a = Mathf.Lerp(from, to, TweenHelper.EaseOut(Mathf.Clamp01(elapsed / dur)));
                scrim.color = c;
                yield return null;
            }
            c.a = to;
            scrim.color = c;
        }
    }
}
