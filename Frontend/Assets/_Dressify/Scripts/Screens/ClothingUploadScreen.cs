using System.Collections;
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
    /// Screen 6 — Clothing Upload
    ///
    /// States: idle → source_picker → selected → processing → success | error
    ///
    /// Inspector setup:
    ///   - UploadArea: RectTransform (dashed border rectangle)
    ///   - UploadIcon: Image (48dp)
    ///   - UploadPromptLabel / UploadSubtextLabel: TextMeshProUGUI
    ///   - PreviewImage: RawImage (hidden when no image)
    ///   - ChangeImageLink: Button (hidden until image selected)
    ///   - DetectionBadge: Image+TextMeshProUGUI (green/yellow pill)
    ///   - ClothingTypeDropdown: TMP_Dropdown (manual override)
    ///   - RemoveBgButton: PrimaryButton
    ///   - ProgressBar: ProgressBar component
    ///   - TryOnButton / SaveToWardrobeButton: Buttons (hidden until success)
    ///   - ErrorBanner: GameObject+TextMeshProUGUI
    ///   - RetryButton: Button
    ///   - SourcePickerSheet: BottomSheet (Camera / Gallery buttons)
    /// </summary>
    public class ClothingUploadScreen : MonoBehaviour
    {
        private enum UploadState { Idle, Selected, Processing, Success, Error }

        [Header("Upload Area")]
        [SerializeField] private GameObject      uploadPromptGroup;
        [SerializeField] private RawImage        previewImage;
        [SerializeField] private Button          changeImageBtn;

        [Header("Detection Badge")]
        [SerializeField] private GameObject      detectionBadge;
        [SerializeField] private TextMeshProUGUI badgeLabel;
        [SerializeField] private Image           badgeBackground;
        [SerializeField] private TMP_Dropdown    clothingTypeDropdown;
        [SerializeField] private GameObject      manualSelectGroup;

        [Header("Actions")]
        [SerializeField] private PrimaryButton   removeBgButton;
        [SerializeField] private ProgressBar     progressBar;
        [SerializeField] private GameObject      progressGroup;
        [SerializeField] private Button          cancelButton;

        [Header("Success")]
        [SerializeField] private GameObject      successActions;
        [SerializeField] private PrimaryButton   tryOnButton;
        [SerializeField] private SecondaryButton saveToWardrobeButton;

        [Header("Error")]
        [SerializeField] private GameObject      errorBanner;
        [SerializeField] private TextMeshProUGUI errorLabel;
        [SerializeField] private Button          retryButton;

        [Header("Source Picker")]
        [SerializeField] private BottomSheet     sourcePickerSheet;
        [SerializeField] private Button          cameraButton;
        [SerializeField] private Button          galleryButton;

        [Header("Navigation")]
        [SerializeField] private Button          backButton;

        private UploadState    _state = UploadState.Idle;
        private byte[]         _imageBytes;
        private string         _imageName = "clothing.jpg";
        private ClothingItem   _uploadedItem;
        private Coroutine      _uploadRoutine;

        // ── Colors ────────────────────────────────────────────────────────────────
        private Color _greenBadge  = new Color(0.133f, 0.788f, 0.478f);
        private Color _yellowBadge = new Color(0.984f, 0.757f, 0.145f);

        private void Start()
        {
            backButton?.onClick.AddListener(() => NavigationManager.Instance.Pop());
            removeBgButton?.OnClick       += HandleRemoveBackground;
            tryOnButton?.OnClick          += HandleTryOn;
            saveToWardrobeButton?.OnClick += HandleSaveToWardrobe;
            retryButton?.onClick.AddListener(HandleRetry);
            cancelButton?.onClick.AddListener(HandleCancel);
            changeImageBtn?.onClick.AddListener(OpenSourcePicker);

            // Source picker
            sourcePickerSheet?.gameObject.SetActive(false);
            cameraButton?.onClick.AddListener(OnCameraSelected);
            galleryButton?.onClick.AddListener(OnGallerySelected);

            SetState(UploadState.Idle);
            AppState.OnUploadProgress += p => progressBar?.SetProgress(p);
        }

        private void OnDestroy() =>
            AppState.OnUploadProgress -= p => progressBar?.SetProgress(p);

        // ── State Machine ─────────────────────────────────────────────────────────

        private void SetState(UploadState state)
        {
            _state = state;
            uploadPromptGroup?.SetActive(state == UploadState.Idle);
            previewImage?.gameObject.SetActive(state != UploadState.Idle);
            changeImageBtn?.gameObject.SetActive(state == UploadState.Selected || state == UploadState.Success);
            removeBgButton?.gameObject.SetActive(state == UploadState.Selected);
            progressGroup?.SetActive(state == UploadState.Processing);
            cancelButton?.gameObject.SetActive(state == UploadState.Processing);
            successActions?.SetActive(state == UploadState.Success);
            errorBanner?.SetActive(state == UploadState.Error);
            detectionBadge?.SetActive(state == UploadState.Selected || state == UploadState.Success);
        }

        // ── Source Picker ─────────────────────────────────────────────────────────

        private void OpenSourcePicker()
        {
            if (sourcePickerSheet != null)
                sourcePickerSheet.Open();
            else
                OnGallerySelected(); // fallback
        }

        private void OnCameraSelected()
        {
            sourcePickerSheet?.Close();
            // Native camera: use NativeCamera plugin or Unity's WebCamTexture
            // For stub: use a test texture
            LoadStubImage();
        }

        private void OnGallerySelected()
        {
            sourcePickerSheet?.Close();
            // Native gallery: use NativeGallery plugin
            // For stub: load a test texture
            LoadStubImage();
        }

        private void LoadStubImage()
        {
            // In production: receive Texture2D from NativeCamera / NativeGallery callbacks
            // then: previewImage.texture = texture; _imageBytes = texture.EncodeToJPG(); etc.
            _imageBytes = new byte[0]; // placeholder
            _imageName  = "clothing.jpg";
            SetState(UploadState.Selected);
            ShowDetectionBadge("Top detected ✓", _greenBadge, isUncertain: false);
        }

        // ── Detection Badge ───────────────────────────────────────────────────────

        private void ShowDetectionBadge(string text, Color color, bool isUncertain)
        {
            if (badgeLabel != null)      badgeLabel.text = text;
            if (badgeBackground != null) badgeBackground.color = color;
            if (manualSelectGroup != null) manualSelectGroup.SetActive(isUncertain);
        }

        // ── Remove Background ─────────────────────────────────────────────────────

        private void HandleRemoveBackground()
        {
            SetState(UploadState.Processing);
            progressBar?.Reset();
            _uploadRoutine = StartCoroutine(UploadRoutine());
        }

        private IEnumerator UploadRoutine()
        {
            var user = AppManager.Instance.CurrentUser;
            yield return ApiService.Instance.UploadImage(
                _imageBytes,
                _imageName,
                user?.Uid ?? "stub_uid",
                p => progressBar?.SetProgress(p),
                OnUploadSuccess,
                OnUploadError
            );
        }

        private void OnUploadSuccess(UploadResponse res)
        {
            _uploadedItem = new ClothingItem
            {
                Id               = res.item_id,
                ProcessedImageUrl = res.processed_image_url,
                Type             = ParseClothingType(res.clothing_type),
                AnchorPoints     = res.anchor_points,
                ConfidenceScore  = res.confidence_score
            };
            SetState(UploadState.Success);
            ShowDetectionBadge("Background removed ✓", _greenBadge, false);
            Toast.Instance?.Show("Background removed!", Components.ToastType.Success);
        }

        private void OnUploadError(string err)
        {
            SetState(UploadState.Error);
            if (errorLabel != null) errorLabel.text = Strings.UploadError;
        }

        private void HandleCancel()
        {
            if (_uploadRoutine != null) StopCoroutine(_uploadRoutine);
            SetState(UploadState.Selected);
        }

        private void HandleRetry() => HandleRemoveBackground();

        // ── Navigation ────────────────────────────────────────────────────────────

        private void HandleTryOn()
        {
            // Store item for try-on screen
            PlayerPrefs.SetString("pending_item_id", _uploadedItem?.Id ?? "");
            NavigationManager.Instance.Push(NavigationManager.Scenes.TryOn);
        }

        private void HandleSaveToWardrobe()
        {
            if (_uploadedItem == null) return;
            StartCoroutine(ApiService.Instance.SaveOutfit(
                new SaveOutfitRequest
                {
                    user_id      = AppManager.Instance.CurrentUser?.Uid,
                    clothing_url = _uploadedItem.ProcessedImageUrl
                },
                _ => {
                    Toast.Instance?.Show("Saved to Wardrobe!", Components.ToastType.Success);
                    AppState.FireWardrobeUpdated();
                },
                err => Toast.Instance?.Show("Save failed. Try again.", Components.ToastType.Error)
            ));
        }

        // ── Helpers ───────────────────────────────────────────────────────────────

        private ClothingType ParseClothingType(string s) => s?.ToLower() switch
        {
            "top"     => ClothingType.Top,
            "bottom"  => ClothingType.Bottom,
            "dress"   => ClothingType.Dress,
            "jacket"  => ClothingType.Jacket,
            _         => ClothingType.Other
        };
    }
}
