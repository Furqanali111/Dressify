using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Horizontal scrollable chip group.
    /// Chips are auto-generated from the Options list.
    /// Inspector setup:
    ///   - ChipContainer: HorizontalLayoutGroup inside a ScrollRect
    ///   - ChipPrefab: prefab with Background Image + Label TMP
    /// </summary>
    public class ChipGroup : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Transform  chipContainer;
        [SerializeField] private GameObject chipPrefab;

        [Header("Settings")]
        [SerializeField] private List<string> options      = new();
        [SerializeField] private bool         multiSelect  = false;
        [SerializeField] private int          defaultIndex = -1;

        private readonly List<ChipItem> _chips = new();
        private readonly HashSet<int>   _selectedIndices = new();

        public event Action<int, string>    OnChipSelected;
        public event Action<List<int>>      OnSelectionChanged;

        // ── Lifecycle ─────────────────────────────────────────────────────────────
        private void Start() => BuildChips();

        // ── Build ─────────────────────────────────────────────────────────────────
        public void SetOptions(List<string> newOptions, int defaultIdx = -1)
        {
            options      = newOptions;
            defaultIndex = defaultIdx;

            foreach (Transform c in chipContainer) Destroy(c.gameObject);
            _chips.Clear();
            _selectedIndices.Clear();
            BuildChips();
        }

        private void BuildChips()
        {
            if (chipPrefab == null || chipContainer == null) return;
            for (int i = 0; i < options.Count; i++)
            {
                int   idx  = i;
                var   go   = Instantiate(chipPrefab, chipContainer);
                var   item = new ChipItem
                {
                    Background = go.GetComponent<Image>(),
                    Label      = go.GetComponentInChildren<TextMeshProUGUI>(),
                    Button     = go.GetComponent<Button>()
                };
                if (item.Label != null) item.Label.text = options[i];
                item.Button?.onClick.AddListener(() => ToggleChip(idx));
                _chips.Add(item);
            }

            if (defaultIndex >= 0 && defaultIndex < _chips.Count)
                SelectChip(defaultIndex, notify: false);
        }

        // ── Selection ─────────────────────────────────────────────────────────────

        private void ToggleChip(int idx)
        {
            if (_selectedIndices.Contains(idx))
            {
                if (multiSelect)
                {
                    _selectedIndices.Remove(idx);
                    RefreshChip(idx, false);
                }
                // single-select: can't deselect the only selected chip
            }
            else
            {
                if (!multiSelect) ClearSelection();
                SelectChip(idx, notify: true);
            }
            OnSelectionChanged?.Invoke(new List<int>(_selectedIndices));
        }

        public void SelectChip(int idx, bool notify = true)
        {
            if (idx < 0 || idx >= _chips.Count) return;
            _selectedIndices.Add(idx);
            RefreshChip(idx, true);
            if (notify) OnChipSelected?.Invoke(idx, options[idx]);
        }

        private void ClearSelection()
        {
            foreach (int i in _selectedIndices) RefreshChip(i, false);
            _selectedIndices.Clear();
        }

        private void RefreshChip(int idx, bool selected)
        {
            if (idx >= _chips.Count) return;
            var chip = _chips[idx];
            if (chip.Background != null)
                chip.Background.color = selected
                    ? DesignSystem.Instance.GetPrimary()
                    : Color.clear;
            if (chip.Label != null)
                chip.Label.color = selected ? Color.white : DesignSystem.Instance.GetTextPrimary();
        }

        public int GetSelectedIndex() =>
            _selectedIndices.Count > 0 ? new List<int>(_selectedIndices)[0] : -1;

        public string GetSelectedValue() =>
            GetSelectedIndex() >= 0 ? options[GetSelectedIndex()] : null;

        // ── Inner type ────────────────────────────────────────────────────────────
        private class ChipItem
        {
            public Image            Background;
            public TextMeshProUGUI  Label;
            public Button           Button;
        }
    }
}
