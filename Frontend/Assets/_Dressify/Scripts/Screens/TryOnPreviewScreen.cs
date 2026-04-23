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
    /// Screen 7 — Try-On Preview (Core Screen)
    ///
    /// Inspector setup:
    ///   - PreviewCanvas: RectTransform (top 65%)
    ///   - AvatarImage: Image (avatar illustration)
    ///   - ClothingOverlay: RectTransform (clothing positioned by overlay engine)
    ///   - ClothingImage: RawImage on ClothingOverlay
    ///   - ZoomInBtn / ZoomOutBtn / ResetBtn / ToggleAvatarBtn: IconButtons
    ///   - LowConfidenceBanner: GameObject (drag handles active)
    ///   - ClothingNameLabel / ClothingTypeLabel: TextMeshProUGUI
    ///   - GetFeedbackBtn: SecondaryButton
    ///   - SaveOutfitBtn: PrimaryButton
    ///   - Skeleton: LoadingSkeleton (shown during rendering)
    ///   - AiFeedbackSheet: AiFeedbackSheet component
    /// </summary>
    public class TryOnPreviewScreen : MonoBehaviour
    {
        private enum TryOnState { Rendering, Success, LowConfidence, Saved }

        [Header("Canvas")]
        [SerializeField] private Image           avatarImage;
        [SerializeField] private RectTransform   clothingOverlay;
        [SerializeField] private RawImage        clothingImage;
        [SerializeField] private LoadingSkeleton skeleton;

        [Header("Overlay Controls")]
        [SerializeField] private Button          zoomInBtn;
        [SerializeField] private Button          zoomOutBtn;
        [SerializeField] private Button          resetBtn;
        [SerializeField] private Button          toggleAvatarBtn;

        [Header("Low-Confidence UI")]
        [SerializeField] private GameObject      lowConfidenceBanner;

        [Header("Bottom Panel")]
        [SerializeField] private TextMeshProUGUI clothingNameLabel;
        [SerializeField] private TextMeshProUGUI clothingTypeLabel;
        [SerializeField] private SecondaryButton getFeedbackBtn;
        [SerializeField] private PrimaryButton   saveOutfitBtn;

        [Header("Navigation")]
        [SerializeField] private Button          backButton;

        [Header("AI Feedback")]
        [SerializeField] private AiFeedbackSheet feedbackSheet;

        private TryOnState   _state;
        private ClothingItem _currentItem;
        private float        _zoomLevel = 1f;
        private Vector2      _basePosition;
        private bool         _avatarVisible = true;
        private bool         _isSaving;

        // Drag support
        private bool    _isDragging;
        private Vector2 _dragOffset;

        private void Start()
        {
            backButton?.onClick.AddListener(() => NavigationManager.Instance.Pop());
            zoomInBtn?.onClick.AddListener(() => AdjustZoom(0.1f));
            zoomOutBtn?.onClick.AddListener(() => AdjustZoom(-0.1f));
            resetBtn?.onClick.AddListener(ResetOverlay);
            toggleAvatarBtn?.onClick.AddListener(ToggleAvatar);

            getFeedbackBtn?.OnClick  += HandleGetFeedback;
            saveOutfitBtn?.OnClick   += HandleSaveOutfit;

            // Receive clothing item from previous screen
            LoadClothingItem();
        }

        // ── Data Loading ──────────────────────────────────────────────────────────

        private void LoadClothingItem()
        {
            SetState(TryOnState.Rendering);
            skeleton?.Show();

            // In production: retrieve ClothingItem from a shared context/cache
            // For stub: create a placeholder
            _currentItem = new ClothingItem
            {
                Name            = "Blue T-Shirt",
                Type            = ClothingType.Top,
                ConfidenceScore = 0.85f,
                AnchorPoints    = new AnchorPoints
                {
                    Shoulder = new Vector2(0.5f, 0.25f),
                    Chest    = new Vector2(0.5f, 0.40f),
                    Waist    = new Vector2(0.5f, 0.60f)
                }
            };

            StartCoroutine(RenderOutfit());
        }

        private IEnumerator RenderOutfit()
        {
            // Simulate loading texture
            yield return new WaitForSeconds(0.8f);
            skeleton?.Hide();

            // Apply overlay using engine
            ClothingOverlayEngine.ApplyOverlay(
                clothingOverlay, avatarImage.rectTransform,
                _currentItem.AnchorPoints, AppManager.Instance.SelectedAvatar
            );
            _basePosition = clothingOverlay.anchoredPosition;

            // Load texture
            if (!string.IsNullOrEmpty(_currentItem.ProcessedImageUrl))
            {
                yield return ApiService.Instance.LoadTexture(
                    _currentItem.ProcessedImageUrl,
                    tex => { if (clothingImage != null) clothingImage.texture = tex; },
                    _ => {}
                );
            }

            if (clothingNameLabel != null) clothingNameLabel.text = _currentItem.Name ?? "Clothing";
            if (clothingTypeLabel != null) clothingTypeLabel.text = $"— {_currentItem.Type}";

            bool isLowConf = _currentItem.IsLowConfidence;
            SetState(isLowConf ? TryOnState.LowConfidence : TryOnState.Success);
        }

        // ── State ─────────────────────────────────────────────────────────────────

        private void SetState(TryOnState state)
        {
            _state = state;
            bool ready = state == TryOnState.Success || state == TryOnState.LowConfidence;
            if (skeleton != null) { if (ready) skeleton.Hide(); else skeleton.Show(); }
            if (lowConfidenceBanner != null) lowConfidenceBanner.SetActive(state == TryOnState.LowConfidence);
            getFeedbackBtn?.SetInteractable(ready);
            saveOutfitBtn?.SetInteractable(ready);
        }

        // ── Zoom / Drag ───────────────────────────────────────────────────────────

        private void AdjustZoom(float delta)
        {
            _zoomLevel = Mathf.Clamp(_zoomLevel + delta, 0.5f, 2.0f);
            if (clothingOverlay != null)
                clothingOverlay.localScale = Vector3.one * _zoomLevel;
        }

        private void ResetOverlay()
        {
            _zoomLevel = 1f;
            if (clothingOverlay != null)
            {
                clothingOverlay.localScale       = Vector3.one;
                clothingOverlay.anchoredPosition = _basePosition;
            }
        }

        private void ToggleAvatar()
        {
            _avatarVisible = !_avatarVisible;
            if (avatarImage != null) avatarImage.enabled = _avatarVisible;
        }

        // Only active when low-confidence; drag handled via EventTrigger in Inspector
        public void OnBeginDrag(UnityEngine.EventSystems.BaseEventData data)
        {
            if (data is UnityEngine.EventSystems.PointerEventData pod)
                _dragOffset = (Vector2)clothingOverlay.position - pod.position;
        }

        public void OnDrag(UnityEngine.EventSystems.BaseEventData data)
        {
            if (data is UnityEngine.EventSystems.PointerEventData pod)
                clothingOverlay.position = pod.position + _dragOffset;
        }

        // ── AI Feedback ───────────────────────────────────────────────────────────

        private void HandleGetFeedback()
        {
            feedbackSheet?.Open(_currentItem);
        }

        // ── Save Outfit ───────────────────────────────────────────────────────────

        private void HandleSaveOutfit()
        {
            if (_isSaving) return;
            _isSaving = true;
            saveOutfitBtn?.SetLoading(true);

            var request = new SaveOutfitRequest
            {
                user_id      = AppManager.Instance.CurrentUser?.Uid ?? "stub",
                avatar_id    = AppManager.Instance.SelectedAvatar.ToString(),
                clothing_url = _currentItem?.ProcessedImageUrl ?? "",
                position     = new[] { clothingOverlay.anchoredPosition.x, clothingOverlay.anchoredPosition.y },
                scale        = new[] { _zoomLevel, _zoomLevel }
            };

            StartCoroutine(ApiService.Instance.SaveOutfit(
                request,
                _ => {
                    _isSaving = false;
                    saveOutfitBtn?.SetLoading(false);
                    saveOutfitBtn?.SetLabel(Strings.OutfitSaved);
                    Toast.Instance?.Show("Outfit saved! 🎉", ToastType.Success);
                    // Confetti burst at button world position
                    Dressify.Utils.ConfettiBurst.Instance?.Burst(
                        saveOutfitBtn != null
                            ? (Vector2)saveOutfitBtn.transform.position
                            : new Vector2(Screen.width * 0.5f, Screen.height * 0.3f)
                    );
                    StartCoroutine(ResetSaveButton());
                    AppState.FireWardrobeUpdated();
                },
                err => {
                    _isSaving = false;
                    saveOutfitBtn?.SetLoading(false);
                    Toast.Instance?.Show("Save failed. Try again.", ToastType.Error);
                }
            ));
        }

        private IEnumerator ResetSaveButton()
        {
            yield return new WaitForSeconds(2f);
            saveOutfitBtn?.SetLabel(Strings.SaveOutfit);
        }
    }
}
