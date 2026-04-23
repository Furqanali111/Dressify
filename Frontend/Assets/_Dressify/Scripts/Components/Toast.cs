using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    public enum ToastType { Success, Error, Info }

    /// <summary>
    /// Bottom toast / snackbar.
    /// Inspector setup:
    ///   - Root: RectTransform anchored to bottom-center
    ///   - CanvasGroup on root (for alpha fades)
    ///   - LeftBorder: Image (4dp wide, colored by type)
    ///   - MessageLabel: TextMeshProUGUI
    ///   - ActionButton: Button + TMP (optional)
    ///
    /// Usage: Toast.Instance.Show("Message", ToastType.Success);
    /// </summary>
    public class Toast : MonoBehaviour
    {
        public static Toast Instance { get; private set; }

        [Header("References")]
        [SerializeField] private RectTransform   root;
        [SerializeField] private CanvasGroup     canvasGroup;
        [SerializeField] private Image           leftBorder;
        [SerializeField] private TextMeshProUGUI messageLabel;
        [SerializeField] private GameObject      actionButtonGo;
        [SerializeField] private TextMeshProUGUI actionButtonLabel;
        [SerializeField] private Button          actionButton;

        [Header("Colors")]
        [SerializeField] private Color successColor = new Color(0.133f, 0.788f, 0.478f);
        [SerializeField] private Color errorColor   = new Color(1f, 0.361f, 0.361f);
        [SerializeField] private Color infoColor    = new Color(0.259f, 0.522f, 0.957f);

        private Coroutine _activeToast;

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
            if (canvasGroup != null) canvasGroup.alpha = 0f;
            if (root != null) root.gameObject.SetActive(false);
        }

        // ── Public API ────────────────────────────────────────────────────────────

        public void Show(string message, ToastType type = ToastType.Info,
                         string actionLabel = null, Action onAction = null,
                         float duration = 3f)
        {
            if (_activeToast != null) StopCoroutine(_activeToast);
            _activeToast = StartCoroutine(ShowRoutine(message, type, actionLabel, onAction, duration));
        }

        // ── Internals ─────────────────────────────────────────────────────────────

        private IEnumerator ShowRoutine(string message, ToastType type,
                                        string actionLabel, Action onAction, float duration)
        {
            // Set content
            if (messageLabel != null) messageLabel.text = message;
            if (leftBorder != null)   leftBorder.color  = GetColor(type);

            // Action button
            bool hasAction = !string.IsNullOrEmpty(actionLabel) && onAction != null;
            if (actionButtonGo != null) actionButtonGo.SetActive(hasAction);
            if (hasAction && actionButtonLabel != null) actionButtonLabel.text = actionLabel;
            if (hasAction && actionButton != null)
            {
                actionButton.onClick.RemoveAllListeners();
                actionButton.onClick.AddListener(() =>
                {
                    onAction?.Invoke();
                    StopCoroutine(_activeToast);
                    StartCoroutine(DismissRoutine());
                });
            }

            root.gameObject.SetActive(true);
            yield return StartCoroutine(TweenHelper.ToastAppear(this, root, canvasGroup, duration));
            root.gameObject.SetActive(false);
        }

        private IEnumerator DismissRoutine()
        {
            yield return StartCoroutine(TweenHelper.FadeTo(canvasGroup, 0f, 0.2f));
            root.gameObject.SetActive(false);
        }

        private Color GetColor(ToastType type) => type switch
        {
            ToastType.Success => successColor,
            ToastType.Error   => errorColor,
            _                 => infoColor
        };
    }
}
