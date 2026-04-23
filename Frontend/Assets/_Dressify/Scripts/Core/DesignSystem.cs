using UnityEngine;

namespace Dressify.Core
{
    /// <summary>
    /// Single source of truth for all design tokens.
    /// Create asset: Assets/_Dressify/ScriptableObjects/DressifyTheme.asset
    /// via  Assets > Create > Dressify > Design System
    /// </summary>
    [CreateAssetMenu(fileName = "DressifyTheme", menuName = "Dressify/Design System")]
    public class DesignSystem : ScriptableObject
    {
        private static DesignSystem _instance;
        public static DesignSystem Instance
        {
            get
            {
                if (_instance == null)
                    _instance = Resources.Load<DesignSystem>("DressifyTheme");
                return _instance;
            }
        }

        [Header("Brand Colors — Light Mode")]
        public Color primary       = new Color(0.424f, 0.388f, 1.000f); // #6C63FF
        public Color primaryDark   = new Color(0.294f, 0.267f, 0.800f); // #4B44CC
        public Color surface       = Color.white;
        public Color background    = new Color(0.961f, 0.957f, 1.000f); // #F5F4FF
        public Color textPrimary   = new Color(0.102f, 0.102f, 0.180f); // #1A1A2E
        public Color textSecondary = new Color(0.420f, 0.420f, 0.541f); // #6B6B8A
        public Color success       = new Color(0.133f, 0.788f, 0.478f); // #22C97A
        public Color error         = new Color(1.000f, 0.361f, 0.361f); // #FF5C5C
        public Color overlay       = new Color(0f, 0f, 0f, 0.55f);

        [Header("Brand Colors — Dark Mode")]
        public Color primaryDarkMode       = new Color(0.659f, 0.612f, 1.000f); // #A89CFF
        public Color primaryDarkDarkMode   = new Color(0.482f, 0.439f, 0.933f); // #7B70EE
        public Color surfaceDarkMode       = new Color(0.110f, 0.110f, 0.180f); // #1C1C2E
        public Color backgroundDarkMode    = new Color(0.051f, 0.051f, 0.102f); // #0D0D1A
        public Color textPrimaryDarkMode   = new Color(0.941f, 0.937f, 1.000f); // #F0EFFF
        public Color textSecondaryDarkMode = new Color(0.600f, 0.600f, 0.733f); // #9999BB
        public Color successDarkMode       = new Color(0.122f, 0.659f, 0.396f); // #1FA865
        public Color errorDarkMode         = new Color(1.000f, 0.439f, 0.439f); // #FF7070

        [Header("Spacing Scale (dp)")]
        public float sp4  =  4f;
        public float sp8  =  8f;
        public float sp12 = 12f;
        public float sp16 = 16f;
        public float sp24 = 24f;
        public float sp32 = 32f;
        public float sp48 = 48f;
        public float sp64 = 64f;

        [Header("Corner Radius (dp)")]
        public float radiusCard       = 20f;
        public float radiusButton     = 14f;
        public float radiusInput      = 12f;
        public float radiusBottomSheet = 24f;
        public float radiusClothing   = 16f;

        [Header("Typography (sp)")]
        public float sizeDisplay  = 28f;
        public float sizeSection  = 20f;
        public float sizeBody     = 16f;
        public float sizeCaption  = 13f;
        public float sizeButton   = 15f;

        // ── Runtime helpers ──────────────────────────────────────────────────────
        private static bool _isDarkMode = false;

        public static void SetDarkMode(bool dark) => _isDarkMode = dark;

        public Color GetPrimary()       => _isDarkMode ? Instance.primaryDarkMode    : Instance.primary;
        public Color GetSurface()       => _isDarkMode ? Instance.surfaceDarkMode    : Instance.surface;
        public Color GetBackground()    => _isDarkMode ? Instance.backgroundDarkMode : Instance.background;
        public Color GetTextPrimary()   => _isDarkMode ? Instance.textPrimaryDarkMode   : Instance.textPrimary;
        public Color GetTextSecondary() => _isDarkMode ? Instance.textSecondaryDarkMode : Instance.textSecondary;
        public Color GetSuccess()       => _isDarkMode ? Instance.successDarkMode    : Instance.success;
        public Color GetError()         => _isDarkMode ? Instance.errorDarkMode      : Instance.error;
    }
}
