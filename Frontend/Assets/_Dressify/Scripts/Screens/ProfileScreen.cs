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
    /// Screen 10 — Profile & Settings
    ///
    /// Inspector setup:
    ///   - AvatarCircle: Image (80dp circle)
    ///   - UserNameLabel: TextMeshProUGUI (20sp bold)
    ///   - EditProfileBtn: Button
    ///   - HeightPill / WeightPill / BodyTypePill: TextMeshProUGUI
    ///   - EditStatsBtn: Button
    ///   - UnitToggle: Toggle
    ///   - NotificationToggle: Toggle
    ///   - ThemeDropdown: TMP_Dropdown
    ///   - SignOutBtn: Button (red text)
    ///   - AppVersionLabel: TextMeshProUGUI
    ///   - ConfirmDialog: GameObject (modal overlay)
    ///   - ConfirmCancelBtn / ConfirmSignOutBtn: Buttons
    /// </summary>
    public class ProfileScreen : MonoBehaviour
    {
        [Header("Profile Header")]
        [SerializeField] private Image           avatarCircle;
        [SerializeField] private TextMeshProUGUI userNameLabel;
        [SerializeField] private Button          editProfileBtn;

        [Header("Body Stats")]
        [SerializeField] private TextMeshProUGUI heightPill;
        [SerializeField] private TextMeshProUGUI weightPill;
        [SerializeField] private TextMeshProUGUI bodyTypePill;
        [SerializeField] private Button          editStatsBtn;

        [Header("Settings")]
        [SerializeField] private Toggle          unitToggle;          // on=metric
        [SerializeField] private Toggle          notificationToggle;
        [SerializeField] private TMP_Dropdown    themeDropdown;
        [SerializeField] private Button          privacyPolicyBtn;
        [SerializeField] private Button          termsBtn;
        [SerializeField] private TextMeshProUGUI appVersionLabel;

        [Header("Sign Out")]
        [SerializeField] private Button          signOutBtn;
        [SerializeField] private GameObject      confirmDialog;
        [SerializeField] private Button          confirmCancelBtn;
        [SerializeField] private Button          confirmSignOutBtn;

        private void Start()
        {
            editProfileBtn?.onClick.AddListener(() =>
                NavigationManager.Instance.Push(NavigationManager.Scenes.ProfileSetup));

            editStatsBtn?.onClick.AddListener(() =>
                NavigationManager.Instance.Push(NavigationManager.Scenes.ProfileSetup));

            unitToggle?.onValueChanged.AddListener(OnUnitToggle);
            notificationToggle?.onValueChanged.AddListener(on => {
                PlayerPrefs.SetInt("notifications", on ? 1 : 0);
            });

            themeDropdown?.onValueChanged.AddListener(OnThemeChanged);

            privacyPolicyBtn?.onClick.AddListener(() =>
                Application.OpenURL("https://dressify.app/privacy"));
            termsBtn?.onClick.AddListener(() =>
                Application.OpenURL("https://dressify.app/terms"));

            signOutBtn?.onClick.AddListener(() => ShowConfirmDialog(true));
            confirmCancelBtn?.onClick.AddListener(() => ShowConfirmDialog(false));
            confirmSignOutBtn?.onClick.AddListener(HandleSignOut);

            ShowConfirmDialog(false);
            PopulateProfile();
        }

        // ── Populate ──────────────────────────────────────────────────────────────

        private void PopulateProfile()
        {
            var user = AppManager.Instance.CurrentUser;
            if (user == null) return;

            if (userNameLabel != null) userNameLabel.text = user.Name ?? "—";

            bool metric = user.IsMetric;
            if (unitToggle != null) unitToggle.isOn = metric;

            if (heightPill != null)
                heightPill.text = metric
                    ? $"{user.HeightCm:F0} cm"
                    : $"{user.HeightCm / 30.48f:F1} ft";

            if (weightPill != null)
                weightPill.text = metric
                    ? $"{user.WeightKg:F0} kg"
                    : $"{user.WeightKg / 0.453592f:F0} lbs";

            if (bodyTypePill != null)
                bodyTypePill.text = user.BodyType.ToString();

            if (appVersionLabel != null)
                appVersionLabel.text = $"Version {Application.version}";

            // Theme: index 0=System, 1=Light, 2=Dark
            string theme = user.Theme ?? "system";
            if (themeDropdown != null)
                themeDropdown.value = theme switch { "light" => 1, "dark" => 2, _ => 0 };
        }

        // ── Settings Handlers ─────────────────────────────────────────────────────

        private void OnUnitToggle(bool isMetric)
        {
            var user = AppManager.Instance.CurrentUser;
            if (user == null) return;
            user.IsMetric = isMetric;
            PopulateProfile();
        }

        private void OnThemeChanged(int idx)
        {
            string theme = idx switch { 1 => "light", 2 => "dark", _ => "system" };
            DesignSystem.SetDarkMode(theme == "dark");
            var user = AppManager.Instance.CurrentUser;
            if (user != null) user.Theme = theme;
            // Trigger global theme refresh here if needed
        }

        // ── Sign Out ──────────────────────────────────────────────────────────────

        private void ShowConfirmDialog(bool show) =>
            confirmDialog?.SetActive(show);

        private void HandleSignOut()
        {
            ShowConfirmDialog(false);
            AuthService.Instance.SignOut();
            NavigationManager.Instance.NavigateToRoot(NavigationManager.Scenes.SignIn);
        }
    }
}
