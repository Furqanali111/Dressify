using System;
using System.Collections;
using UnityEngine;
using Dressify.Models;
using Dressify.Core;

namespace Dressify.Services
{
    /// <summary>
    /// Handles Firebase Auth + Google Sign-In.
    ///
    /// SETUP: Import the following packages into your Unity project:
    ///   1. Firebase Unity SDK (Authentication module):
    ///      https://firebase.google.com/docs/unity/setup
    ///   2. Google Sign-In Unity Plugin:
    ///      https://github.com/googlesamples/google-signin-unity/releases
    ///
    /// Add your google-services.json to Assets/ (Android)
    /// and GoogleService-Info.plist to Assets/ (iOS).
    ///
    /// Replace the #if FIREBASE_AUTH blocks when the SDK is imported.
    /// </summary>
    public class AuthService : MonoBehaviour
    {
        public static AuthService Instance { get; private set; }

        [Header("Google Sign-In")]
        [SerializeField] private string webClientId = "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com";

        // Cached id token for API calls
        public string IdToken  { get; private set; }
        public string Uid      { get; private set; }

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private void Start()
        {
            InitializeFirebase();
        }

        // ── Firebase Init ────────────────────────────────────────────────────────

        private void InitializeFirebase()
        {
            // When Firebase SDK is imported, replace with:
            // Firebase.FirebaseApp.CheckAndFixDependenciesAsync().ContinueWith(task => { ... });
            Debug.Log("[AuthService] Firebase init (stub). Import Firebase SDK to enable.");
        }

        // ── Google Sign-In ────────────────────────────────────────────────────────

        /// <summary>Trigger Google Sign-In flow.</summary>
        public void SignInWithGoogle()
        {
            StartCoroutine(SignInRoutine());
        }

        private IEnumerator SignInRoutine()
        {
            // ── STUB ─────────────────────────────────────────────────────────────
            // When Firebase + Google Sign-In SDKs are imported, replace this with:
            //
            // GoogleSignIn.Configuration = new GoogleSignInConfiguration {
            //     WebClientId = webClientId,
            //     RequestIdToken = true,
            //     RequestEmail = true
            // };
            // var task = GoogleSignIn.DefaultInstance.SignIn();
            // yield return new WaitUntil(() => task.IsCompleted);
            // if (task.IsFaulted) { AppState.FireAuthError("Sign-in cancelled."); yield break; }
            // string googleIdToken = task.Result.IdToken;
            // var credential = Firebase.Auth.GoogleAuthProvider.GetCredential(googleIdToken, null);
            // var authTask = Firebase.Auth.FirebaseAuth.DefaultInstance.SignInWithCredentialAsync(credential);
            // yield return new WaitUntil(() => authTask.IsCompleted);
            // if (authTask.Exception != null) { AppState.FireAuthError(authTask.Exception.Message); yield break; }
            // var firebaseUser = authTask.Result;
            // IdToken = await firebaseUser.TokenAsync(false);
            // Uid = firebaseUser.UserId;
            // ──────────────────────────────────────────────────────────────────────

            // Stub: simulate success after 1 second
            yield return new WaitForSeconds(1f);

            IdToken = "stub_id_token";
            Uid     = "stub_uid";

            var profile = new UserProfile
            {
                Uid      = Uid,
                Name     = "Test User",
                Email    = "test@dressify.app",
                PhotoUrl = ""
            };
            AppManager.Instance.CurrentUser = profile;
            SecureStorageService.Instance.SaveToken(IdToken);
            AppState.FireUserSignedIn(profile);
        }

        // ── Token Management ─────────────────────────────────────────────────────

        /// <summary>Get a fresh token. Call before every API request.</summary>
        public IEnumerator GetFreshToken(Action<string> onToken, Action<string> onError)
        {
            // When Firebase SDK is imported, replace with:
            // var task = Firebase.Auth.FirebaseAuth.DefaultInstance.CurrentUser.TokenAsync(true);
            // yield return new WaitUntil(() => task.IsCompleted);
            // if (task.Exception != null) { onError?.Invoke(task.Exception.Message); yield break; }
            // onToken?.Invoke(task.Result);

            // Stub
            yield return null;
            if (string.IsNullOrEmpty(IdToken))
            {
                onError?.Invoke("No authenticated user.");
                yield break;
            }
            onToken?.Invoke(IdToken);
        }

        // ── Sign Out ──────────────────────────────────────────────────────────────

        public void SignOut()
        {
            // Firebase.Auth.FirebaseAuth.DefaultInstance.SignOut();
            // GoogleSignIn.DefaultInstance.SignOut();
            IdToken = null;
            Uid     = null;
            AppManager.Instance.ClearSession();
            AppState.FireUserSignedOut();
        }
    }
}
