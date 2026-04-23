using System.Collections;
using UnityEngine;
using UnityEngine.Networking;
using Dressify.Core;

namespace Dressify.Services
{
    /// <summary>
    /// Firebase Storage helpers.
    ///
    /// SETUP: Requires Firebase Unity SDK (Storage module).
    /// https://firebase.google.com/docs/unity/setup
    ///
    /// For MVP, this wraps the signed-URL pattern:
    ///   - Backend generates a signed download URL
    ///   - Client downloads via that URL using UnityWebRequest
    /// No raw public URLs are ever used.
    /// </summary>
    public class StorageService : MonoBehaviour
    {
        public static StorageService Instance { get; private set; }

        [Header("Firebase Storage")]
        [SerializeField] private string storageBucket = "YOUR_PROJECT.appspot.com";

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        // ── Download texture via signed URL ───────────────────────────────────────

        /// <summary>
        /// Download a texture from a Firebase Storage signed URL.
        /// Use ApiService.LoadTexture() for non-Storage URLs.
        /// </summary>
        public IEnumerator DownloadTexture(
            string signedUrl,
            System.Action<Texture2D> onSuccess,
            System.Action<string>    onError)
        {
            using var req = UnityWebRequestTexture.GetTexture(signedUrl);

            // Inject auth token as bearer for extra security layer
            string token = null;
            yield return AuthService.Instance.GetFreshToken(t => token = t, _ => { });
            if (!string.IsNullOrEmpty(token))
                req.SetRequestHeader("Authorization", $"Bearer {token}");

            yield return req.SendWebRequest();

            if (req.result != UnityWebRequest.Result.Success)
            {
                onError?.Invoke(req.error ?? "Download failed");
                yield break;
            }
            onSuccess?.Invoke(DownloadHandlerTexture.GetContent(req));
        }

        // ── Upload to Firebase Storage via REST ───────────────────────────────────

        /// <summary>
        /// Upload bytes directly to Firebase Storage REST API.
        /// Returns the download URL.
        ///
        /// When Firebase SDK is imported, replace with:
        ///   FirebaseStorage.DefaultInstance.GetReference(path).PutBytesAsync(bytes)
        /// </summary>
        public IEnumerator UploadBytes(
            byte[]                   bytes,
            string                   storagePath,
            string                   contentType,
            System.Action<string>    onSuccess,   // returns download URL
            System.Action<string>    onError,
            System.Action<float>     onProgress = null)
        {
            string token = null;
            yield return AuthService.Instance.GetFreshToken(t => token = t, _ => { });

            // Firebase REST upload URL
            string url = $"https://firebasestorage.googleapis.com/v0/b/{storageBucket}/o" +
                         $"?uploadType=media&name={UnityWebRequest.EscapeURL(storagePath)}";

            using var req = new UnityWebRequest(url, "POST");
            req.uploadHandler   = new UploadHandlerRaw(bytes);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", contentType);
            if (!string.IsNullOrEmpty(token))
                req.SetRequestHeader("Authorization", $"Bearer {token}");

            var op = req.SendWebRequest();
            while (!op.isDone)
            {
                onProgress?.Invoke(req.uploadProgress);
                yield return null;
            }

            if (req.result != UnityWebRequest.Result.Success)
            {
                onError?.Invoke(req.error ?? "Storage upload failed");
                yield break;
            }

            // Parse mediaLink from response JSON
            string mediaLink = ParseMediaLink(req.downloadHandler.text);
            onSuccess?.Invoke(mediaLink);
        }

        // ── Helpers ───────────────────────────────────────────────────────────────

        private string ParseMediaLink(string json)
        {
            // Minimal JSON parse for "mediaLink" field
            const string key = "\"mediaLink\":\"";
            int start = json.IndexOf(key);
            if (start < 0) return "";
            start += key.Length;
            int end = json.IndexOf('"', start);
            return end > start ? json.Substring(start, end - start) : "";
        }
    }
}
