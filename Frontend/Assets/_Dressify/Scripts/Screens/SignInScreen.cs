using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;
using Dressify.Services;
using Dressify.Components;

namespace Dressify.Screens
{
    /// <summary>
    /// Screen 2 — Google Sign-In
    ///
    /// Inspector setup:
    ///   - TitleLabel: TextMeshProUGUI
    ///   - SubtitleLabel: TextMeshProUGUI
    ///   - SignInButton: PrimaryButton component
    ///   - ErrorBanner: GameObject with TextMeshProUGUI (hidden by default)
    ///   - ErrorLabel: TextMeshProUGUI inside banner
    ///   - TermsLabel: TextMeshProUGUI (hyperlink styled)
    ///
    /// States: idle | loading | error | success
    /// </summary>
    public class SignInScreen : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private TextMeshProUGUI titleLabel;
        [SerializeField] private TextMeshProUGUI subtitleLabel;
        [SerializeField] private PrimaryButton   signInButton;
        [SerializeField] private GameObject      errorBanner;
        [SerializeField] private TextMeshProUGUI errorLabel;

        private void Start()
        {
            if (titleLabel != null)    titleLabel.text    = Strings.WelcomeTitle;
            if (subtitleLabel != null) subtitleLabel.text = Strings.WelcomeSubtitle;

            if (signInButton != null)
            {
                signInButton.SetLabel(Strings.SignInWithGoogle);
                signInButton.OnClick += HandleSignIn;
            }

            HideError();

            // Subscribe to auth events
            AppState.OnUserSignedIn += OnSignedIn;
            AppState.OnAuthError    += OnAuthError;
        }

        private void OnDestroy()
        {
            AppState.OnUserSignedIn -= OnSignedIn;
            AppState.OnAuthError    -= OnAuthError;
        }

        // ── Handlers ──────────────────────────────────────────────────────────────

        private void HandleSignIn()
        {
            HideError();
            signInButton?.SetLoading(true);
            AuthService.Instance.SignInWithGoogle();
        }

        private void OnSignedIn(Models.UserProfile profile)
        {
            signInButton?.SetLoading(false);
            bool needsProfile  = !AppManager.Instance.HasCompletedProfile;
            bool needsAvatar   = AppManager.Instance.SelectedAvatar == Models.AvatarType.Average
                                 && AppManager.Instance.IsFirstLaunch;

            if (needsProfile)
                NavigationManager.Instance.Push(NavigationManager.Scenes.ProfileSetup);
            else if (needsAvatar)
                NavigationManager.Instance.Push(NavigationManager.Scenes.AvatarSelect);
            else
                NavigationManager.Instance.NavigateToRoot(NavigationManager.Scenes.Home);
        }

        private void OnAuthError(string message)
        {
            signInButton?.SetLoading(false);
            ShowError(Strings.SignInError);
        }

        // ── UI helpers ────────────────────────────────────────────────────────────

        private void ShowError(string message)
        {
            if (errorBanner != null) errorBanner.SetActive(true);
            if (errorLabel  != null) errorLabel.text = message;
        }

        private void HideError()
        {
            if (errorBanner != null) errorBanner.SetActive(false);
        }
    }
}
