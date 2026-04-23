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
    /// Screen 5 — Home / Wardrobe Hub
    ///
    /// Inspector setup:
    ///   - GreetingLabel: TextMeshProUGUI
    ///   - AvatarThumb: Image (circular, 40dp)
    ///   - NotificationBell: IconButton
    ///   - QuickActions: 4 IconButton children (NewOutfit, MyWardrobe, SavedLooks, StyleTips)
    ///   - RecentScroll: ScrollRect (horizontal)
    ///   - OutfitCardPrefab: prefab
    ///   - EmptyState: GameObject (hidden when outfits exist)
    ///   - EmptyStateButton: PrimaryButton → upload
    ///   - Skeleton: LoadingSkeleton (shown while loading)
    ///   - SeeAllBtn: Button
    /// </summary>
    public class HomeScreen : MonoBehaviour
    {
        [Header("Top Bar")]
        [SerializeField] private TextMeshProUGUI greetingLabel;
        [SerializeField] private Image           avatarThumb;

        [Header("Quick Actions")]
        [SerializeField] private Button btnNewOutfit;
        [SerializeField] private Button btnWardrobe;
        [SerializeField] private Button btnSavedLooks;
        [SerializeField] private Button btnStyleTips;

        [Header("Recent Outfits")]
        [SerializeField] private Transform       recentContainer;
        [SerializeField] private GameObject      outfitCardPrefab;
        [SerializeField] private Button          seeAllButton;
        [SerializeField] private GameObject      emptyState;
        [SerializeField] private Button          emptyStateCTA;

        [Header("Loading")]
        [SerializeField] private LoadingSkeleton skeleton;

        private List<Outfit> _recentOutfits = new();

        private void Start()
        {
            SetGreeting();

            // Quick actions
            btnNewOutfit?.onClick.AddListener(() =>
                NavigationManager.Instance.Push(NavigationManager.Scenes.Upload));
            btnWardrobe?.onClick.AddListener(() =>
                NavigationManager.Instance.SwitchTab(NavigationManager.Scenes.Wardrobe));
            btnSavedLooks?.onClick.AddListener(() =>
                NavigationManager.Instance.SwitchTab(NavigationManager.Scenes.Wardrobe));
            btnStyleTips?.onClick.AddListener(() =>
                Toast.Instance?.Show("AI Style Tips — Coming soon!", Components.ToastType.Info));

            seeAllButton?.onClick.AddListener(() =>
                NavigationManager.Instance.SwitchTab(NavigationManager.Scenes.Wardrobe));
            emptyStateCTA?.onClick.AddListener(() =>
                NavigationManager.Instance.Push(NavigationManager.Scenes.Upload));

            // Refresh on save
            AppState.OnOutfitSaved   += _ => LoadRecentOutfits();
            AppState.OnWardrobeUpdated   += LoadRecentOutfits;

            LoadRecentOutfits();
        }

        private void OnDestroy()
        {
            AppState.OnOutfitSaved   -= _ => LoadRecentOutfits();
            AppState.OnWardrobeUpdated   -= LoadRecentOutfits;
        }

        // ── Data ──────────────────────────────────────────────────────────────────

        private void LoadRecentOutfits()
        {
            skeleton?.Show();
            SetEmptyState(false);

            var user = AppManager.Instance.CurrentUser;
            if (user == null || string.IsNullOrEmpty(user.Uid))
            {
                skeleton?.Hide();
                SetEmptyState(true);
                return;
            }

            StartCoroutine(ApiService.Instance.GetWardrobe(
                user.Uid,
                OnWardrobeLoaded,
                err => { skeleton?.Hide(); SetEmptyState(true); }
            ));
        }

        private void OnWardrobeLoaded(WardrobeResponse res)
        {
            skeleton?.Hide();
            _recentOutfits = res?.saved_outfits ?? new List<Outfit>();

            // Clear old cards
            foreach (Transform c in recentContainer) Destroy(c.gameObject);

            if (_recentOutfits.Count == 0)
            {
                SetEmptyState(true);
                return;
            }

            SetEmptyState(false);
            // Show at most 5 most recent
            int count = Mathf.Min(_recentOutfits.Count, 5);
            for (int i = 0; i < count; i++)
                SpawnOutfitCard(_recentOutfits[i]);
        }

        private void SpawnOutfitCard(Outfit outfit)
        {
            if (outfitCardPrefab == null || recentContainer == null) return;
            var go   = Instantiate(outfitCardPrefab, recentContainer);
            var name = go.transform.Find("OutfitName")?.GetComponent<TextMeshProUGUI>();
            var rating = go.transform.Find("RatingBadge")?.GetComponent<TextMeshProUGUI>();

            if (name != null)   name.text = outfit.Name ?? "Outfit";
            if (rating != null && outfit.AiFeedback != null)
                rating.text = $"★ {outfit.AiFeedback.Score:F1}";

            var btn = go.GetComponent<Button>();
            btn?.onClick.AddListener(() =>
            {
                // Navigate to try-on preview with this outfit loaded
                // (TryOnPreviewScreen reads from AppState)
                NavigationManager.Instance.Push(NavigationManager.Scenes.TryOn);
            });
        }

        // ── UI helpers ────────────────────────────────────────────────────────────

        private void SetGreeting()
        {
            var user = AppManager.Instance.CurrentUser;
            string name = user?.Name ?? "there";
            if (greetingLabel != null)
                greetingLabel.text = string.Format(Strings.Greeting, name);
        }

        private void SetEmptyState(bool empty)
        {
            if (emptyState != null) emptyState.SetActive(empty);
            if (recentContainer != null) recentContainer.gameObject.SetActive(!empty);
        }
    }
}
