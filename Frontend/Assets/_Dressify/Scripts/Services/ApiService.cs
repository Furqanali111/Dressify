using System;
using System.Collections;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;
using Dressify.Models;
using Dressify.Core;

namespace Dressify.Services
{
    /// <summary>
    /// All FastAPI REST calls.
    /// Set BASE_URL to your backend endpoint.
    /// All requests automatically inject the Firebase idToken as Bearer header.
    /// </summary>
    public class ApiService : MonoBehaviour
    {
        public static ApiService Instance { get; private set; }

        [Header("Backend")]
        [SerializeField] private string baseUrl = "http://localhost:8000";

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        // ── Upload Image ─────────────────────────────────────────────────────────

        /// <summary>
        /// POST /upload — sends image bytes as multipart/form-data.
        /// Reports progress via onProgress (0–1).
        /// </summary>
        public IEnumerator UploadImage(
            byte[]           imageBytes,
            string           fileName,
            string           userId,
            Action<float>    onProgress,
            Action<UploadResponse> onSuccess,
            Action<string>   onError)
        {
            string url = $"{baseUrl}/upload";

            var form = new WWWForm();
            form.AddBinaryData("image", imageBytes, fileName, "image/jpeg");
            form.AddField("user_id", userId);

            using var req = UnityWebRequest.Post(url, form);
            yield return InjectAuth(req);

            var op = req.SendWebRequest();

            while (!op.isDone)
            {
                onProgress?.Invoke(req.uploadProgress);
                AppState.FireUploadProgress(req.uploadProgress);
                yield return null;
            }

            if (req.result != UnityWebRequest.Result.Success)
            {
                string err = req.error ?? "Upload failed";
                AppState.FireUploadError(err);
                onError?.Invoke(err);
                yield break;
            }

            var response = JsonUtility.FromJson<UploadResponse>(req.downloadHandler.text);
            onSuccess?.Invoke(response);
        }

        // ── Get AI Feedback ──────────────────────────────────────────────────────

        /// <summary>POST /feedback</summary>
        public IEnumerator GetFeedback(
            FeedbackRequest request,
            Action<FeedbackResponse> onSuccess,
            Action<string> onError)
        {
            string url  = $"{baseUrl}/feedback";
            string json = JsonUtility.ToJson(request);
            byte[] body = Encoding.UTF8.GetBytes(json);

            using var req = new UnityWebRequest(url, "POST");
            req.uploadHandler   = new UploadHandlerRaw(body);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            yield return InjectAuth(req);

            yield return req.SendWebRequest();

            if (req.result != UnityWebRequest.Result.Success)
            {
                string err = req.error ?? "Feedback request failed";
                AppState.FireFeedbackError(err);
                onError?.Invoke(err);
                yield break;
            }

            var response = JsonUtility.FromJson<FeedbackResponse>(req.downloadHandler.text);
            onSuccess?.Invoke(response);
        }

        // ── Save Outfit ──────────────────────────────────────────────────────────

        /// <summary>POST /save-outfit</summary>
        public IEnumerator SaveOutfit(
            SaveOutfitRequest request,
            Action<SaveOutfitResponse> onSuccess,
            Action<string> onError)
        {
            string url  = $"{baseUrl}/save-outfit";
            string json = JsonUtility.ToJson(request);
            byte[] body = Encoding.UTF8.GetBytes(json);

            using var req = new UnityWebRequest(url, "POST");
            req.uploadHandler   = new UploadHandlerRaw(body);
            req.downloadHandler = new DownloadHandlerBuffer();
            req.SetRequestHeader("Content-Type", "application/json");
            yield return InjectAuth(req);

            yield return req.SendWebRequest();

            if (req.result != UnityWebRequest.Result.Success)
            {
                string err = req.error ?? "Save failed";
                AppState.FireSaveError(err);
                onError?.Invoke(err);
                yield break;
            }

            var response = JsonUtility.FromJson<SaveOutfitResponse>(req.downloadHandler.text);
            AppState.FireOutfitSaved(null);  // caller populates outfit object
            onSuccess?.Invoke(response);
        }

        // ── Get Wardrobe ─────────────────────────────────────────────────────────

        /// <summary>GET /wardrobe?user_id={userId}</summary>
        public IEnumerator GetWardrobe(
            string userId,
            Action<WardrobeResponse> onSuccess,
            Action<string> onError)
        {
            string url = $"{baseUrl}/wardrobe?user_id={userId}";

            using var req = UnityWebRequest.Get(url);
            yield return InjectAuth(req);

            yield return req.SendWebRequest();

            if (req.result != UnityWebRequest.Result.Success)
            {
                onError?.Invoke(req.error ?? "Failed to load wardrobe");
                yield break;
            }

            var response = JsonUtility.FromJson<WardrobeResponse>(req.downloadHandler.text);
            onSuccess?.Invoke(response);
        }

        // ── Load Texture from URL ────────────────────────────────────────────────

        public IEnumerator LoadTexture(
            string url,
            Action<Texture2D> onSuccess,
            Action<string> onError)
        {
            using var req = UnityWebRequestTexture.GetTexture(url);
            yield return InjectAuth(req);
            yield return req.SendWebRequest();

            if (req.result != UnityWebRequest.Result.Success)
            {
                onError?.Invoke(req.error);
                yield break;
            }
            onSuccess?.Invoke(DownloadHandlerTexture.GetContent(req));
        }

        // ── Auth Injection Helper ─────────────────────────────────────────────────

        private IEnumerator InjectAuth(UnityWebRequest req)
        {
            string token = null;
            string error = null;
            yield return AuthService.Instance.GetFreshToken(
                t => token = t,
                e => error = e
            );

            if (!string.IsNullOrEmpty(token))
                req.SetRequestHeader("Authorization", $"Bearer {token}");
        }
    }
}
