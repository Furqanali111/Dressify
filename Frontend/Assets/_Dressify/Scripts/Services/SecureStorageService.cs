using System;
using System.Collections;
using UnityEngine;

namespace Dressify.Services
{
    /// <summary>
    /// Encrypted local storage for sensitive tokens.
    /// Uses AES encryption so tokens are never stored in plaintext via PlayerPrefs.
    ///
    /// Note: For true security on Android/iOS, use the Keystore via a Unity plugin.
    /// This implementation provides a reasonable level of obfuscation for MVP.
    /// </summary>
    public class SecureStorageService : MonoBehaviour
    {
        public static SecureStorageService Instance { get; private set; }

        // AES key/IV — in production, derive these from device-unique ID + a server-side secret.
        private const string AesKey = "DressifyKey12345";  // 16 chars = 128-bit
        private const string AesIv  = "DressifyIV123456";  // 16 chars

        private const string PrefToken = "drfy_tok";

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        public void SaveToken(string idToken)
        {
            string encrypted = Encrypt(idToken);
            PlayerPrefs.SetString(PrefToken, encrypted);
            PlayerPrefs.Save();
        }

        public string LoadToken()
        {
            string raw = PlayerPrefs.GetString(PrefToken, "");
            if (string.IsNullOrEmpty(raw)) return null;
            try { return Decrypt(raw); }
            catch { return null; }
        }

        public void ClearTokens()
        {
            PlayerPrefs.DeleteKey(PrefToken);
            PlayerPrefs.Save();
        }

        // ── AES Encrypt / Decrypt ─────────────────────────────────────────────────

        private string Encrypt(string plainText)
        {
            byte[] key   = System.Text.Encoding.UTF8.GetBytes(AesKey);
            byte[] iv    = System.Text.Encoding.UTF8.GetBytes(AesIv);
            byte[] data  = System.Text.Encoding.UTF8.GetBytes(plainText);

            using var aes   = System.Security.Cryptography.Aes.Create();
            aes.Key = key;
            aes.IV  = iv;

            using var ms  = new System.IO.MemoryStream();
            using var cs  = new System.Security.Cryptography.CryptoStream(
                ms, aes.CreateEncryptor(), System.Security.Cryptography.CryptoStreamMode.Write);
            cs.Write(data, 0, data.Length);
            cs.FlushFinalBlock();
            return Convert.ToBase64String(ms.ToArray());
        }

        private string Decrypt(string cipherText)
        {
            byte[] key  = System.Text.Encoding.UTF8.GetBytes(AesKey);
            byte[] iv   = System.Text.Encoding.UTF8.GetBytes(AesIv);
            byte[] data = Convert.FromBase64String(cipherText);

            using var aes = System.Security.Cryptography.Aes.Create();
            aes.Key = key;
            aes.IV  = iv;

            using var ms  = new System.IO.MemoryStream();
            using var cs  = new System.Security.Cryptography.CryptoStream(
                ms, aes.CreateDecryptor(), System.Security.Cryptography.CryptoStreamMode.Write);
            cs.Write(data, 0, data.Length);
            cs.FlushFinalBlock();
            return System.Text.Encoding.UTF8.GetString(ms.ToArray());
        }
    }
}
