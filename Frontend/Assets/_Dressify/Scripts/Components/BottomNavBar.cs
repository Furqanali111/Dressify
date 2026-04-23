using System;
using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Persistent bottom navigation bar (3 tabs: Home, Wardrobe, Profile).
    /// Inspector setup (per tab):
    ///   - TabButton[i]:  Button
    ///   - TabIcon[i]:    Image (24dp icon)
    ///   - TabLabel[i]:   TextMeshProUGUI (12sp)
    ///   - ActiveDot[i]:  Image (small circle below icon — hidden when inactive)
    /// </summary>
    public class BottomNavBar : MonoBehaviour
    {
        public static BottomNavBar Instance { get; private set; }

        [Header("Tab Buttons")]
        [SerializeField] private Button[] tabButtons  = new Button[3];
        [SerializeField] private Image[]  tabIcons    = new Image[3];
        [SerializeField] private TextMeshProUGUI[] tabLabels = new TextMeshProUGUI[3];
        [SerializeField] private GameObject[] activeDots = new GameObject[3];

        [Header("Scene Names")]
        [SerializeField] private string[] sceneNames = { "Home", "Wardrobe", "Profile" };

        [Header("Colors")]
        [SerializeField] private Color activeColor;
        [SerializeField] private Color inactiveColor = new Color(0.6f, 0.6f, 0.6f);

        private int _activeTab = 0;

        public event Action<int> OnTabChanged;

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);

            activeColor = DesignSystem.Instance.GetPrimary();

            for (int i = 0; i < tabButtons.Length; i++)
            {
                int idx = i;
                tabButtons[i]?.onClick.AddListener(() => SelectTab(idx));
            }
            RefreshVisuals();
        }

        /// <summary>Switch to tab without navigation (use when scene is already loaded).</summary>
        public void SetActiveTab(int idx)
        {
            _activeTab = Mathf.Clamp(idx, 0, tabButtons.Length - 1);
            RefreshVisuals();
        }

        public void SelectTab(int idx)
        {
            if (idx == _activeTab) return;
            _activeTab = Mathf.Clamp(idx, 0, tabButtons.Length - 1);
            RefreshVisuals();
            OnTabChanged?.Invoke(_activeTab);
            if (NavigationManager.Instance != null)
                NavigationManager.Instance.SwitchTab(sceneNames[_activeTab]);
        }

        private void RefreshVisuals()
        {
            for (int i = 0; i < tabButtons.Length; i++)
            {
                bool isActive = i == _activeTab;
                if (tabIcons[i] != null)  tabIcons[i].color  = isActive ? activeColor : inactiveColor;
                if (tabLabels[i] != null) tabLabels[i].color  = isActive ? activeColor : inactiveColor;
                if (activeDots[i] != null) activeDots[i].SetActive(isActive);
            }
        }
    }
}
