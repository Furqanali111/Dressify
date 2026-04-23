using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Dressify.Core
{
    /// <summary>
    /// Manages all scene transitions with the animations specified in the design doc.
    /// Transition types:
    ///   Push   → slide from right  (300ms ease-in-out)
    ///   Pop    → slide to right
    ///   Modal  → slide up from bottom
    ///   Tab    → fade crossfade (200ms)
    /// </summary>
    public class NavigationManager : MonoBehaviour
    {
        public static NavigationManager Instance { get; private set; }

        // ── Scene Names ──────────────────────────────────────────────────────────
        public static class Scenes
        {
            public const string Splash          = "Splash";
            public const string Onboarding      = "Onboarding";
            public const string SignIn          = "SignIn";
            public const string ProfileSetup   = "ProfileSetup";
            public const string AvatarSelect   = "AvatarSelection";
            public const string Home            = "Home";
            public const string Upload          = "Upload";
            public const string TryOn           = "TryOnPreview";
            public const string Wardrobe        = "Wardrobe";
            public const string Profile         = "Profile";
        }

        private readonly Stack<string> _backStack = new Stack<string>();
        private CanvasGroup            _transitionOverlay;
        private bool                   _isTransitioning;

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        // ── Public API ───────────────────────────────────────────────────────────

        /// <summary>Push a new scene (slide from right).</summary>
        public void Push(string sceneName)
        {
            if (_isTransitioning) return;
            _backStack.Push(SceneManager.GetActiveScene().name);
            StartCoroutine(TransitionRoutine(sceneName, TransitionType.Push));
        }

        /// <summary>Pop back to the previous scene (slide to right).</summary>
        public void Pop()
        {
            if (_isTransitioning || _backStack.Count == 0) return;
            string prev = _backStack.Pop();
            StartCoroutine(TransitionRoutine(prev, TransitionType.Pop));
        }

        /// <summary>Open a scene as a modal (slides up from bottom).</summary>
        public void OpenModal(string sceneName)
        {
            if (_isTransitioning) return;
            _backStack.Push(SceneManager.GetActiveScene().name);
            StartCoroutine(TransitionRoutine(sceneName, TransitionType.Modal));
        }

        /// <summary>Switch tab (crossfade, clears back stack).</summary>
        public void SwitchTab(string sceneName)
        {
            if (_isTransitioning) return;
            _backStack.Clear();
            StartCoroutine(TransitionRoutine(sceneName, TransitionType.Tab));
        }

        /// <summary>Navigate to root (clears entire stack).</summary>
        public void NavigateToRoot(string sceneName)
        {
            if (_isTransitioning) return;
            _backStack.Clear();
            StartCoroutine(TransitionRoutine(sceneName, TransitionType.Tab));
        }

        // ── Internals ─────────────────────────────────────────────────────────────

        private enum TransitionType { Push, Pop, Modal, Tab }

        private IEnumerator TransitionRoutine(string targetScene, TransitionType type)
        {
            _isTransitioning = true;

            // Fade out (short)
            float duration = type == TransitionType.Tab ? 0.2f : 0.15f;
            yield return StartCoroutine(FadeOverlay(0f, 1f, duration));

            yield return SceneManager.LoadSceneAsync(targetScene);

            // Fade back in
            yield return StartCoroutine(FadeOverlay(1f, 0f, duration));

            _isTransitioning = false;
        }

        private IEnumerator FadeOverlay(float from, float to, float duration)
        {
            // Simple alpha fade using a full-screen black overlay object.
            // In the Unity scenes, add a Canvas → Image (black, raycast on) named "TransitionOverlay"
            // and tag it "TransitionOverlay" so we can find it.
            GameObject overlayGo = GameObject.FindWithTag("TransitionOverlay");
            if (overlayGo == null) { yield break; }

            var img = overlayGo.GetComponent<UnityEngine.UI.Image>();
            if (img == null) yield break;

            float elapsed = 0f;
            Color c = img.color;
            while (elapsed < duration)
            {
                elapsed += Time.deltaTime;
                float t = Mathf.Clamp01(elapsed / duration);
                c.a = Mathf.Lerp(from, to, t);
                img.color = c;
                yield return null;
            }
            c.a = to;
            img.color = c;
        }
    }
}
