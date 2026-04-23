using UnityEngine;
using Dressify.Models;
using Dressify.Services;

namespace Dressify.Core
{
    /// <summary>
    /// Persistent singleton that survives scene loads.
    /// Holds user session data and coordinates top-level app state.
    /// </summary>
    public class AppManager : MonoBehaviour
    {
        // ── Singleton ────────────────────────────────────────────────────────────
        public static AppManager Instance { get; private set; }

        // ── Session Data ─────────────────────────────────────────────────────────
        public UserProfile CurrentUser   { get; set; }
        public AvatarType  SelectedAvatar { get; set; } = AvatarType.Average;
        public bool        IsFirstLaunch  { get; private set; }

        // ── Constants ────────────────────────────────────────────────────────────
        private const string PrefKeyFirstLaunch = "dressify_first_launch";
        private const string PrefKeyUserId      = "dressify_user_id";

        // ── Lifecycle ────────────────────────────────────────────────────────────
        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
            Bootstrap();
        }

        private void Bootstrap()
        {
            IsFirstLaunch = !PlayerPrefs.HasKey(PrefKeyFirstLaunch);
            if (IsFirstLaunch)
                PlayerPrefs.SetInt(PrefKeyFirstLaunch, 1);

            Application.targetFrameRate = 60;
            Screen.orientation = ScreenOrientation.Portrait;
        }

        // ── Helpers ──────────────────────────────────────────────────────────────
        public void ClearSession()
        {
            CurrentUser    = null;
            SelectedAvatar = AvatarType.Average;
            SecureStorageService.Instance?.ClearTokens();
        }

        public bool HasCompletedProfile =>
            CurrentUser != null && !string.IsNullOrEmpty(CurrentUser.Name);
    }
}
