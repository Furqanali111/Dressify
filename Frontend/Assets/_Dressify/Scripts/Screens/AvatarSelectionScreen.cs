using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;
using Dressify.Models;
using Dressify.Components;

namespace Dressify.Screens
{
    /// <summary>
    /// Screen 4 — Avatar Selection
    ///
    /// Inspector setup:
    ///   - AvatarCardContainer: HorizontalLayoutGroup inside a ScrollRect
    ///   - AvatarCardPrefab: 140×240dp card prefab (Image + NameLabel + CheckBadge)
    ///   - UseAvatarButton: PrimaryButton
    ///   - BackButton: Button
    ///
    /// Data: 5 avatar types — Slim / Athletic / Average / Curvy / Plus
    /// </summary>
    public class AvatarSelectionScreen : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Transform       cardContainer;
        [SerializeField] private GameObject      cardPrefab;
        [SerializeField] private PrimaryButton   useAvatarButton;
        [SerializeField] private Button          backButton;

        private readonly List<AvatarCardItem> _cards = new();
        private int _selectedIndex = -1;

        private static readonly string[] AvatarNames = { "Slim", "Athletic", "Average", "Curvy", "Plus" };

        private void Start()
        {
            backButton?.onClick.AddListener(() => NavigationManager.Instance.Pop());
            useAvatarButton?.OnClick += HandleUseAvatar;
            useAvatarButton?.SetInteractable(false);

            BuildCards();
        }

        // ── Build ─────────────────────────────────────────────────────────────────

        private void BuildCards()
        {
            for (int i = 0; i < AvatarNames.Length; i++)
            {
                int idx = i;
                var go  = Instantiate(cardPrefab, cardContainer);

                var item = new AvatarCardItem
                {
                    Root      = go.GetComponent<RectTransform>(),
                    CardImage = go.transform.Find("AvatarImage")?.GetComponent<Image>(),
                    NameLabel = go.GetComponentInChildren<TextMeshProUGUI>(),
                    CheckBadge = go.transform.Find("CheckBadge")?.gameObject,
                    Border    = go.transform.Find("Border")?.GetComponent<Image>(),
                    Button    = go.GetComponent<Button>()
                };

                if (item.NameLabel != null) item.NameLabel.text = AvatarNames[i];
                if (item.CheckBadge != null) item.CheckBadge.SetActive(false);

                item.Button?.onClick.AddListener(() => SelectCard(idx));
                _cards.Add(item);
            }
        }

        // ── Selection ─────────────────────────────────────────────────────────────

        private void SelectCard(int idx)
        {
            if (idx == _selectedIndex) return;

            // Deselect previous
            if (_selectedIndex >= 0 && _selectedIndex < _cards.Count)
            {
                var prev = _cards[_selectedIndex];
                SetCardSelected(prev, false);
                StartCoroutine(TweenHelper.CardDeselect(this, prev.Root));
            }

            _selectedIndex = idx;
            var card = _cards[idx];
            SetCardSelected(card, true);
            StartCoroutine(TweenHelper.CardSelect(this, card.Root));

            useAvatarButton?.SetInteractable(true);
        }

        private void SetCardSelected(AvatarCardItem card, bool selected)
        {
            var primary  = DesignSystem.Instance.GetPrimary();
            if (card.Border != null)
                card.Border.color = selected ? primary : Color.clear;
            if (card.CheckBadge != null)
                card.CheckBadge.SetActive(selected);
        }

        // ── CTA ───────────────────────────────────────────────────────────────────

        private void HandleUseAvatar()
        {
            if (_selectedIndex < 0) return;
            AppManager.Instance.SelectedAvatar = (AvatarType)_selectedIndex;
            NavigationManager.Instance.NavigateToRoot(NavigationManager.Scenes.Home);
        }

        // ── Inner type ────────────────────────────────────────────────────────────

        private class AvatarCardItem
        {
            public RectTransform  Root;
            public Image          CardImage;
            public TextMeshProUGUI NameLabel;
            public GameObject     CheckBadge;
            public Image          Border;
            public Button         Button;
        }
    }
}
