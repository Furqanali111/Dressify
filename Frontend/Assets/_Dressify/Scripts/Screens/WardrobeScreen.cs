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
    /// Screen 9 — Wardrobe
    ///
    /// Inspector setup:
    ///   - ClothingTab / SavedTab: Buttons (tab headers)
    ///   - ClothingPanel / SavedPanel: GameObjects (panel switcher)
    ///   - FilterChips: ChipGroup (All/Tops/Bottoms/Dresses/Jackets)
    ///   - ClothingGrid: GridLayoutGroup inside ScrollRect
    ///   - ClothingCardPrefab: prefab
    ///   - SavedGrid: GridLayoutGroup inside ScrollRect
    ///   - OutfitCardPrefab: prefab
    ///   - EmptyClothing / EmptySaved: GameObjects
    ///   - FAB: IconButton (bottom-right, 56dp purple)
    ///   - Skeleton: LoadingSkeleton
    ///   - ContextMenu: GameObject (popup with Try On / Rename / Delete)
    /// </summary>
    public class WardrobeScreen : MonoBehaviour
    {
        private enum WardrobeTab { Clothing, Saved }

        [Header("Tabs")]
        [SerializeField] private Button clothingTabBtn;
        [SerializeField] private Button savedTabBtn;
        [SerializeField] private GameObject clothingPanel;
        [SerializeField] private GameObject savedPanel;
        [SerializeField] private Image clothingTabLine;
        [SerializeField] private Image savedTabLine;

        [Header("Clothing Tab")]
        [SerializeField] private ChipGroup   filterChips;
        [SerializeField] private Transform   clothingGrid;
        [SerializeField] private GameObject  clothingCardPrefab;
        [SerializeField] private GameObject  emptyClothing;

        [Header("Saved Tab")]
        [SerializeField] private Transform   savedGrid;
        [SerializeField] private GameObject  outfitCardPrefab;
        [SerializeField] private GameObject  emptySaved;

        [Header("Controls")]
        [SerializeField] private IconButton  fab;
        [SerializeField] private LoadingSkeleton skeleton;

        [Header("Context Menu")]
        [SerializeField] private GameObject  contextMenuGo;
        [SerializeField] private Button      ctxTryOn;
        [SerializeField] private Button      ctxRename;
        [SerializeField] private Button      ctxDelete;

        private WardrobeTab          _activeTab = WardrobeTab.Clothing;
        private List<ClothingItem>   _clothingItems = new();
        private List<Outfit>         _savedOutfits  = new();
        private ClothingItem         _ctxItem;
        private Outfit               _ctxOutfit;
        private string               _activeFilter  = "All";

        private void Start()
        {
            clothingTabBtn?.onClick.AddListener(() => SwitchTab(WardrobeTab.Clothing));
            savedTabBtn?.onClick.AddListener(() => SwitchTab(WardrobeTab.Saved));

            filterChips?.SetOptions(
                new List<string> { "All", "Tops", "Bottoms", "Dresses", "Jackets" },
                defaultIdx: 0
            );
            if (filterChips != null)
                filterChips.OnChipSelected += (_, val) => {
                    _activeFilter = val;
                    PopulateClothingGrid();
                };

            fab?.OnClick += () => NavigationManager.Instance.Push(NavigationManager.Scenes.Upload);

            contextMenuGo?.SetActive(false);
            ctxTryOn?.onClick.AddListener(CtxTryOn);
            ctxRename?.onClick.AddListener(CtxRename);
            ctxDelete?.onClick.AddListener(CtxDelete);

            AppState.OnWardrobeUpdated += LoadWardrobe;
            SwitchTab(WardrobeTab.Clothing);
            LoadWardrobe();
        }

        private void OnDestroy() => AppState.OnWardrobeUpdated -= LoadWardrobe;

        // ── Tab Switching ─────────────────────────────────────────────────────────

        private void SwitchTab(WardrobeTab tab)
        {
            _activeTab = tab;
            clothingPanel?.SetActive(tab == WardrobeTab.Clothing);
            savedPanel?.SetActive(tab == WardrobeTab.Saved);

            var primary = DesignSystem.Instance.GetPrimary();
            var gone    = Color.clear;
            if (clothingTabLine != null) clothingTabLine.color = tab == WardrobeTab.Clothing ? primary : gone;
            if (savedTabLine    != null) savedTabLine.color    = tab == WardrobeTab.Saved    ? primary : gone;
        }

        // ── Data ──────────────────────────────────────────────────────────────────

        private void LoadWardrobe()
        {
            skeleton?.Show();
            var uid = AppManager.Instance.CurrentUser?.Uid ?? "stub";
            StartCoroutine(ApiService.Instance.GetWardrobe(uid,
                res => {
                    skeleton?.Hide();
                    _clothingItems = res?.clothing_items ?? new List<ClothingItem>();
                    _savedOutfits  = res?.saved_outfits  ?? new List<Outfit>();
                    PopulateClothingGrid();
                    PopulateSavedGrid();
                },
                err => {
                    skeleton?.Hide();
                    Toast.Instance?.Show("Failed to load wardrobe.", ToastType.Error);
                }
            ));
        }

        // ── Grids ─────────────────────────────────────────────────────────────────

        private void PopulateClothingGrid()
        {
            foreach (Transform c in clothingGrid) Destroy(c.gameObject);

            var filtered = _clothingItems.FindAll(item =>
                _activeFilter == "All" ||
                item.Type.ToString() == _activeFilter.TrimEnd('s'));

            if (emptyClothing != null) emptyClothing.SetActive(filtered.Count == 0);
            foreach (var item in filtered) SpawnClothingCard(item);
        }

        private void PopulateSavedGrid()
        {
            foreach (Transform c in savedGrid) Destroy(c.gameObject);
            if (emptySaved != null) emptySaved.SetActive(_savedOutfits.Count == 0);
            foreach (var outfit in _savedOutfits) SpawnOutfitCard(outfit);
        }

        private void SpawnClothingCard(ClothingItem item)
        {
            if (clothingCardPrefab == null) return;
            var go  = Instantiate(clothingCardPrefab, clothingGrid);
            var lbl = go.transform.Find("ItemName")?.GetComponent<TextMeshProUGUI>();
            if (lbl != null) lbl.text = item.Name ?? item.Type.ToString();

            var btn = go.GetComponent<Button>();
            btn?.onClick.AddListener(() => {
                _ctxItem = item;
                contextMenuGo?.SetActive(true);
            });
        }

        private void SpawnOutfitCard(Outfit outfit)
        {
            if (outfitCardPrefab == null) return;
            var go     = Instantiate(outfitCardPrefab, savedGrid);
            var lbl    = go.transform.Find("OutfitName")?.GetComponent<TextMeshProUGUI>();
            var rating = go.transform.Find("RatingBadge")?.GetComponent<TextMeshProUGUI>();

            if (lbl    != null) lbl.text    = outfit.Name ?? "Outfit";
            if (rating != null && outfit.AiFeedback != null)
                rating.text = $"★ {outfit.AiFeedback.Score:F1}";

            var btn = go.GetComponent<Button>();
            btn?.onClick.AddListener(() => {
                _ctxOutfit = outfit;
                contextMenuGo?.SetActive(true);
            });
        }

        // ── Context Menu ──────────────────────────────────────────────────────────

        private void CtxTryOn()
        {
            contextMenuGo?.SetActive(false);
            NavigationManager.Instance.Push(NavigationManager.Scenes.TryOn);
        }

        private void CtxRename()
        {
            contextMenuGo?.SetActive(false);
            Toast.Instance?.Show("Rename — Coming soon", ToastType.Info);
        }

        private void CtxDelete()
        {
            contextMenuGo?.SetActive(false);
            Toast.Instance?.Show("Deleted", ToastType.Success);
            AppState.FireWardrobeUpdated();
        }
    }
}
