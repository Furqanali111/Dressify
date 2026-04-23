using System;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Outlined secondary button variant.
    /// Inspector setup:
    ///   - Background: Image (transparent, 14dp radius outline sprite)
    ///   - Border: Outline Image (primary color)
    ///   - LabelText: TextMeshProUGUI (primary color, 15sp)
    /// </summary>
    [RequireComponent(typeof(Button))]
    public class SecondaryButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI labelText;
        [SerializeField] private Image           background;

        [Header("Settings")]
        [SerializeField] private string label = "Button";

        public event Action OnClick;

        private Button _button;

        private void Awake()
        {
            _button = GetComponent<Button>();
            _button.onClick.AddListener(() => OnClick?.Invoke());
            if (labelText != null) labelText.text = label;
        }

        public void OnPointerDown(PointerEventData e)
        {
            if (!_button.interactable) return;
            // Light primary fill on press
            if (background != null)
            {
                var c = DesignSystem.Instance.GetPrimary();
                c.a = 0.1f;
                background.color = c;
            }
            StartCoroutine(TweenHelper.ScaleTo(transform, Vector3.one * 0.97f, 0.1f, TweenHelper.EaseOut));
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (!_button.interactable) return;
            if (background != null) background.color = Color.clear;
            StartCoroutine(TweenHelper.ScaleTo(transform, Vector3.one, 0.1f, TweenHelper.EaseOut));
        }

        public void SetLabel(string text)
        {
            label = text;
            if (labelText != null) labelText.text = text;
        }

        public void SetInteractable(bool interactable) =>
            _button.interactable = interactable;
    }
}
