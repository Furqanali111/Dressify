using System;
using Dressify.Models;

namespace Dressify.Core
{
    /// <summary>
    /// Global application state events. Screens subscribe to what they need.
    /// All events fire on the main thread.
    /// </summary>
    public static class AppState
    {
        // ── Auth ─────────────────────────────────────────────────────────────────
        public static event Action<UserProfile> OnUserSignedIn;
        public static event Action              OnUserSignedOut;
        public static event Action<string>      OnAuthError;

        // ── Upload ───────────────────────────────────────────────────────────────
        public static event Action<float>         OnUploadProgress;   // 0–1
        public static event Action<ClothingItem>  OnUploadComplete;
        public static event Action<string>        OnUploadError;

        // ── Try-On ───────────────────────────────────────────────────────────────
        public static event Action<Outfit>   OnOutfitRendered;
        public static event Action<string>   OnRenderError;

        // ── Save Outfit ───────────────────────────────────────────────────────────
        public static event Action<Outfit>  OnOutfitSaved;
        public static event Action<string>  OnSaveError;

        // ── AI Feedback ───────────────────────────────────────────────────────────
        public static event Action<AiFeedback> OnFeedbackReceived;
        public static event Action<string>     OnFeedbackError;

        // ── Wardrobe ──────────────────────────────────────────────────────────────
        public static event Action OnWardrobeUpdated;

        // ── Fire helpers ─────────────────────────────────────────────────────────
        public static void FireUserSignedIn(UserProfile p)       => OnUserSignedIn?.Invoke(p);
        public static void FireUserSignedOut()                   => OnUserSignedOut?.Invoke();
        public static void FireAuthError(string msg)             => OnAuthError?.Invoke(msg);
        public static void FireUploadProgress(float p)           => OnUploadProgress?.Invoke(p);
        public static void FireUploadComplete(ClothingItem item) => OnUploadComplete?.Invoke(item);
        public static void FireUploadError(string msg)           => OnUploadError?.Invoke(msg);
        public static void FireOutfitRendered(Outfit o)          => OnOutfitRendered?.Invoke(o);
        public static void FireRenderError(string msg)           => OnRenderError?.Invoke(msg);
        public static void FireOutfitSaved(Outfit o)             => OnOutfitSaved?.Invoke(o);
        public static void FireSaveError(string msg)             => OnSaveError?.Invoke(msg);
        public static void FireFeedbackReceived(AiFeedback f)    => OnFeedbackReceived?.Invoke(f);
        public static void FireFeedbackError(string msg)         => OnFeedbackError?.Invoke(msg);
        public static void FireWardrobeUpdated()                 => OnWardrobeUpdated?.Invoke();
    }
}
