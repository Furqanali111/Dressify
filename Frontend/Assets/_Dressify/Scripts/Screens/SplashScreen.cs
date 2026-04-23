using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;
using Dressify.Services;

namespace Dressify.Screens
{
    /// <summary>
    /// Screen 1 — Splash / Entry Point
    ///
    /// Inspector setup:
    ///   - LogoGroup: CanvasGroup on logo container
    ///   - LogoRect:  RectTransform of logo container
    ///   - TaglineLabel: TextMeshProUGUI
    ///   - BackgroundImage: Image (gradient set via sprite)
    ///   - SpinnerGo: GameObject (loading spinner below logo)
    ///
    /// States: loading → new_user → returning_user
    /// </summary>
    public class SplashScreen : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private CanvasGroup     logoGroup;
        [SerializeField] private RectTransform   logoRect;
        [SerializeField] private TextMeshProUGUI taglineLabel;
        [SerializeField] private GameObject      spinnerGo;

        private void Start()
        {
            if (taglineLabel != null)
                taglineLabel.text = Strings.Tagline;

            StartCoroutine(SplashRoutine());
        }

        private IEnumerator SplashRoutine()
        {
            // Logo entrance animation: fade-in + scale-up 400ms
            yield return StartCoroutine(TweenHelper.LogoEntrance(this, logoRect, logoGroup));

            // Shimmer effect across logo
            StartCoroutine(ShimmerLogo());

            // Show spinner
            if (spinnerGo != null) spinnerGo.SetActive(true);
            StartCoroutine(SpinSpinner());

            // Give Firebase up to 3s to resolve auth state
            float timeout = 3f;
            float elapsed = 0f;
            bool  resolved = false;

            // In real build: listen to Firebase OnAuthStateChanged
            // For stub: wait 1.5s then decide
            yield return new WaitForSeconds(1.5f);
            resolved = true;

            if (!resolved) yield return new WaitForSeconds(timeout - elapsed);
            if (spinnerGo != null) spinnerGo.SetActive(false);

            // Route based on session
            bool isReturning = !string.IsNullOrEmpty(SecureStorageService.Instance?.LoadToken());
            bool isFirstLaunch = AppManager.Instance.IsFirstLaunch;

            if (isFirstLaunch)
                NavigationManager.Instance.NavigateToRoot(NavigationManager.Scenes.Onboarding);
            else if (isReturning)
                NavigationManager.Instance.NavigateToRoot(NavigationManager.Scenes.Home);
            else
                NavigationManager.Instance.NavigateToRoot(NavigationManager.Scenes.SignIn);
        }

        private IEnumerator ShimmerLogo()
        {
            // Ping-pong logo brightness over 2 cycles
            var img = logoRect?.GetComponent<Image>();
            if (img == null) yield break;
            Color original = img.color;
            Color bright   = Color.Lerp(original, Color.white, 0.4f);

            for (int i = 0; i < 2; i++)
            {
                yield return StartCoroutine(TweenHelper.FadeGraphic(img, bright.a, 0.25f));
                yield return StartCoroutine(TweenHelper.FadeGraphic(img, original.a, 0.25f));
            }
        }

        private IEnumerator SpinSpinner()
        {
            if (spinnerGo == null) yield break;
            var rt = spinnerGo.GetComponent<RectTransform>();
            while (spinnerGo.activeSelf)
            {
                rt.Rotate(0f, 0f, -360f * Time.deltaTime);
                yield return null;
            }
        }
    }
}
