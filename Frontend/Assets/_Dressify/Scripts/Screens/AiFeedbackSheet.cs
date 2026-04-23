using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;
using Dressify.Models;
using Dressify.Components;
using Dressify.Services;

namespace Dressify.Screens
{
    /// <summary>
    /// Screen 8 — AI Styling Feedback (Bottom Sheet)
    ///
    /// Inspector setup (on the BottomSheet child):
    ///   - RatingArc: RatingArc component
    ///   - VerdictLabel: TextMeshProUGUI
    ///   - SuggestionContainer: VerticalLayoutGroup (ScrollRect)
    ///   - SuggestionCardPrefab: prefab (icon + text + expand)
    ///   - RegenerateButton: Button (secondary)
    ///   - SaveAndFeedbackButton: PrimaryButton
    ///   - CloseButton: Button
    ///   - SheetTitle: TextMeshProUGUI
    /// </summary>
    public class AiFeedbackSheet : MonoBehaviour
    {
        [Header("Components")]
        [SerializeField] private BottomSheet     bottomSheet;
        [SerializeField] private RatingArc       ratingArc;
        [SerializeField] private TextMeshProUGUI verdictLabel;
        [SerializeField] private TextMeshProUGUI sheetTitle;

        [Header("Suggestions")]
        [SerializeField] private Transform       suggestionContainer;
        [SerializeField] private GameObject      suggestionCardPrefab;

        [Header("Actions")]
        [SerializeField] private Button          regenerateButton;
        [SerializeField] private PrimaryButton   saveAndFeedbackButton;
        [SerializeField] private Button          closeButton;

        private ClothingItem _currentItem;
        private AiFeedback   _cachedFeedback;
        private bool         _isLoading;

        private void Awake()
        {
            regenerateButton?.onClick.AddListener(FetchFeedback);
            closeButton?.onClick.AddListener(() => bottomSheet?.Close());
            saveAndFeedbackButton?.OnClick += HandleSaveWithFeedback;

            AppState.OnFeedbackReceived += OnFeedbackReceived;
            AppState.OnFeedbackError    += OnFeedbackError;
        }

        private void OnDestroy()
        {
            AppState.OnFeedbackReceived -= OnFeedbackReceived;
            AppState.OnFeedbackError    -= OnFeedbackError;
        }

        // ── Public API ────────────────────────────────────────────────────────────

        public void Open(ClothingItem item)
        {
            _currentItem = item;
            bottomSheet?.Open();

            if (_cachedFeedback != null)
            {
                DisplayFeedback(_cachedFeedback);
                return;
            }
            FetchFeedback();
        }

        // ── Fetch ─────────────────────────────────────────────────────────────────

        private void FetchFeedback()
        {
            if (_isLoading) return;
            _isLoading = true;
            ratingArc?.SetLoading(true);
            if (verdictLabel != null) verdictLabel.text = Strings.Loading;
            ClearSuggestions();

            var request = new FeedbackRequest
            {
                user_id      = AppManager.Instance.CurrentUser?.Uid ?? "stub",
                outfit_id    = _currentItem?.Id ?? "stub_id",
                avatar_type  = AppManager.Instance.SelectedAvatar.ToString(),
                clothing_type = _currentItem?.Type.ToString() ?? "Top"
            };

            StartCoroutine(ApiService.Instance.GetFeedback(
                request,
                OnFeedbackSuccess,
                err => AppState.FireFeedbackError(err)
            ));
        }

        private void OnFeedbackSuccess(FeedbackResponse res)
        {
            var feedback = new AiFeedback
            {
                Score    = res.score,
                Verdict  = res.verdict,
                Suggestions = new List<Suggestion>()
            };
            if (res.suggestions != null)
                foreach (var s in res.suggestions)
                    feedback.Suggestions.Add(new Suggestion
                    {
                        Category = s.category,
                        Text     = s.text,
                        IconName = s.icon,
                        ColorHex = s.color
                    });

            _cachedFeedback = feedback;
            AppState.FireFeedbackReceived(feedback);
        }

        private void OnFeedbackReceived(AiFeedback feedback)
        {
            _isLoading = false;
            ratingArc?.SetLoading(false);
            _cachedFeedback = feedback;
            DisplayFeedback(feedback);
        }

        private void OnFeedbackError(string err)
        {
            _isLoading = false;
            ratingArc?.SetLoading(false);
            if (verdictLabel != null) verdictLabel.text = Strings.FeedbackError;
            Toast.Instance?.Show(Strings.FeedbackError, ToastType.Error);
        }

        // ── Display ───────────────────────────────────────────────────────────────

        private void DisplayFeedback(AiFeedback feedback)
        {
            ratingArc?.SetScore(feedback.Score);
            if (verdictLabel != null) verdictLabel.text = feedback.Verdict;

            ClearSuggestions();
            if (feedback.Suggestions == null) return;
            foreach (var s in feedback.Suggestions)
                SpawnSuggestionCard(s);
        }

        private void SpawnSuggestionCard(Suggestion s)
        {
            if (suggestionCardPrefab == null || suggestionContainer == null) return;
            var go   = Instantiate(suggestionCardPrefab, suggestionContainer);
            var cat  = go.transform.Find("CategoryLabel")?.GetComponent<TextMeshProUGUI>();
            var txt  = go.transform.Find("SuggestionText")?.GetComponent<TextMeshProUGUI>();

            if (cat != null) cat.text  = s.Category;
            if (txt != null) txt.text  = s.Text;

            // Expand on tap
            var btn = go.GetComponent<Button>();
            bool expanded = false;
            btn?.onClick.AddListener(() =>
            {
                expanded = !expanded;
                if (txt != null) txt.overflowMode = expanded
                    ? TextOverflowModes.Overflow
                    : TextOverflowModes.Ellipsis;
            });
        }

        private void ClearSuggestions()
        {
            if (suggestionContainer == null) return;
            foreach (Transform c in suggestionContainer) Destroy(c.gameObject);
        }

        // ── Save ──────────────────────────────────────────────────────────────────

        private void HandleSaveWithFeedback()
        {
            saveAndFeedbackButton?.SetLoading(true);
            var req = new SaveOutfitRequest
            {
                user_id           = AppManager.Instance.CurrentUser?.Uid ?? "stub",
                clothing_url      = _currentItem?.ProcessedImageUrl ?? "",
                avatar_id         = AppManager.Instance.SelectedAvatar.ToString(),
                ai_feedback_json  = JsonUtility.ToJson(_cachedFeedback)
            };

            StartCoroutine(ApiService.Instance.SaveOutfit(req,
                _ => {
                    saveAndFeedbackButton?.SetLoading(false);
                    Toast.Instance?.Show("Outfit & Feedback saved! 🎉", ToastType.Success);
                    AppState.FireWardrobeUpdated();
                    bottomSheet?.Close();
                },
                err => {
                    saveAndFeedbackButton?.SetLoading(false);
                    Toast.Instance?.Show("Save failed.", ToastType.Error);
                }
            ));
        }
    }
}
