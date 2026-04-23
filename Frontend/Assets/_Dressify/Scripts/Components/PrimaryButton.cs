using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Reusable primary button.
    /// Inspector setup:
    ///   - Background: Image (primary color, 14dp radius via sprite/sliced)
    ///   - LabelText: TextMeshProUGUI ("Button", white, 15sp, 600 weight)
    ///   - Spinner: GameObject with spinning Image (hidden by default)
    /// </summary>
    [RequireComponent(typeof(Button))]
    public class PrimaryButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI labelText;
        [SerializeField] private GameObject      spinner;
        [SerializeField] private Image           background;
        [SerializeField] private CanvasGroup     canvasGroup;

        [Header("Settings")]
        [SerializeField] private string label = "Button";

        private Button    _button;
        private bool      _isLoading;
        private Coroutine _spinnerRoutine;

        // ── Events ───────────────────────────────────────────────────────────────
        public event Action OnClick;

        // ── Lifecycle ─────────────────────────────────────────────────────────────
        private void Awake()
        {
            _button = GetComponent<Button>();
            _button.onClick.AddListener(() => OnClick?.Invoke());
            if (labelText != null) labelText.text = label;
            SetSpinnerVisible(false);
        }

        // ── Press animation ───────────────────────────────────────────────────────
        public void OnPointerDown(PointerEventData e)
        {
            if (!_button.interactable || _isLoading) return;
            StartCoroutine(TweenHelper.ScaleTo(transform, Vector3.one * 0.97f, 0.1f, TweenHelper.EaseOut));
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (!_button.interactable || _isLoading) return;
            StartCoroutine(TweenHelper.ScaleTo(transform, Vector3.one, 0.1f, TweenHelper.EaseOut));
        }

        // ── Public API ────────────────────────────────────────────────────────────
        public void SetLabel(string text)
        {
            label = text;
            if (labelText != null) labelText.text = text;
        }

        public void SetLoading(bool loading)
        {
            _isLoading = loading;
            _button.interactable = !loading;
            if (labelText != null) labelText.gameObject.SetActive(!loading);
            SetSpinnerVisible(loading);
        }

        public void SetInteractable(bool interactable)
        {
            _button.interactable = interactable;
            if (canvasGroup != null)
                canvasGroup.alpha = interactable ? 1f : 0.4f;
        }

        // ── Internals ─────────────────────────────────────────────────────────────
        private void SetSpinnerVisible(bool visible)
        {
            if (spinner == null) return;
            spinner.SetActive(visible);
            if (visible && _spinnerRoutine == null)
                _spinnerRoutine = StartCoroutine(SpinRoutine());
            else if (!visible && _spinnerRoutine != null)
            {
                StopCoroutine(_spinnerRoutine);
                _spinnerRoutine = null;
            }
        }

        private IEnumerator SpinRoutine()
        {
            var img = spinner.GetComponent<Image>();
            while (true)
            {
                if (img != null)
                    img.transform.Rotate(0f, 0f, -360f * Time.deltaTime);
                yield return null;
            }
        }
    }
}
