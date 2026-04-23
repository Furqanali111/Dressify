using System;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Animated input field with floating label and validation error.
    /// Inspector setup:
    ///   - InputField: TMP_InputField (52dp height, 12dp radius background)
    ///   - FloatingLabel: TextMeshProUGUI (label that floats up on focus)
    ///   - ErrorLabel: TextMeshProUGUI (red, hidden by default)
    ///   - BorderImage: Image (1dp stroke, changes color on state)
    /// </summary>
    public class DressifyInputField : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private TMP_InputField   inputField;
        [SerializeField] private TextMeshProUGUI  floatingLabel;
        [SerializeField] private TextMeshProUGUI  errorLabel;
        [SerializeField] private Image            borderImage;
        [SerializeField] private RectTransform    labelRect;

        [Header("Settings")]
        [SerializeField] private string labelText     = "Label";
        [SerializeField] private string placeholderText = "";
        [SerializeField] private TMP_InputField.ContentType contentType = TMP_InputField.ContentType.Standard;

        // ── Colors ────────────────────────────────────────────────────────────────
        private Color _idleBorderColor  = new Color(0.80f, 0.80f, 0.80f);
        private Color _focusBorderColor;
        private Color _errorBorderColor;

        // ── Label positions ───────────────────────────────────────────────────────
        private Vector2 _labelDown = new Vector2(16f, 0f);    // inside field
        private Vector2 _labelUp   = new Vector2(16f, 26f);   // floated above
        private float   _labelDownSize = 16f;
        private float   _labelUpSize   = 12f;

        public string Value => inputField != null ? inputField.text : "";
        public event Action<string> OnValueChanged;
        public event Action         OnEndEdit;

        private void Awake()
        {
            _focusBorderColor = DesignSystem.Instance.GetPrimary();
            _errorBorderColor = DesignSystem.Instance.GetError();

            if (floatingLabel != null)
            {
                floatingLabel.text = labelText;
                labelRect.anchoredPosition = _labelDown;
                floatingLabel.fontSize = _labelDownSize;
                floatingLabel.color = DesignSystem.Instance.GetTextSecondary();
            }

            if (errorLabel != null) errorLabel.gameObject.SetActive(false);
            if (inputField == null) return;

            inputField.contentType = contentType;
            if (inputField.placeholder is TextMeshProUGUI ph)
                ph.text = placeholderText;

            inputField.onSelect.AddListener(_ => OnFocus());
            inputField.onDeselect.AddListener(_ => OnBlur());
            inputField.onValueChanged.AddListener(v => OnValueChanged?.Invoke(v));
            inputField.onEndEdit.AddListener(_ => OnEndEdit?.Invoke());
        }

        // ── Focus / Blur ──────────────────────────────────────────────────────────

        private void OnFocus()
        {
            SetBorderColor(_focusBorderColor);
            if (string.IsNullOrEmpty(inputField.text))
                FloatLabel(true);
        }

        private void OnBlur()
        {
            if (string.IsNullOrEmpty(inputField.text))
                FloatLabel(false);
            SetBorderColor(_idleBorderColor);
        }

        private void FloatLabel(bool up)
        {
            if (labelRect == null || floatingLabel == null) return;
            StartCoroutine(AnimateLabel(up));
        }

        private System.Collections.IEnumerator AnimateLabel(bool up)
        {
            Vector2 from = labelRect.anchoredPosition;
            Vector2 to   = up ? _labelUp : _labelDown;
            float fromSz = floatingLabel.fontSize;
            float toSz   = up ? _labelUpSize : _labelDownSize;
            Color fromCol = floatingLabel.color;
            Color toCol   = up ? DesignSystem.Instance.GetPrimary() : DesignSystem.Instance.GetTextSecondary();

            float dur = 0.15f, elapsed = 0f;
            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                float t = TweenHelper.EaseOut(Mathf.Clamp01(elapsed / dur));
                labelRect.anchoredPosition = Vector2.Lerp(from, to, t);
                floatingLabel.fontSize     = Mathf.Lerp(fromSz, toSz, t);
                floatingLabel.color        = Color.Lerp(fromCol, toCol, t);
                yield return null;
            }
            labelRect.anchoredPosition = to;
            floatingLabel.fontSize     = toSz;
            floatingLabel.color        = toCol;
        }

        // ── Public API ────────────────────────────────────────────────────────────

        public void ShowError(string message)
        {
            if (errorLabel != null)
            {
                errorLabel.text = message;
                errorLabel.gameObject.SetActive(true);
            }
            SetBorderColor(_errorBorderColor);
        }

        public void ClearError()
        {
            if (errorLabel != null) errorLabel.gameObject.SetActive(false);
            SetBorderColor(_idleBorderColor);
        }

        public void SetText(string text)
        {
            if (inputField == null) return;
            inputField.text = text;
            if (!string.IsNullOrEmpty(text)) FloatLabel(true);
        }

        private void SetBorderColor(Color c)
        {
            if (borderImage != null) borderImage.color = c;
        }
    }
}
