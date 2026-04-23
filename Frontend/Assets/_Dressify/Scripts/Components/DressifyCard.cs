using UnityEngine;
using UnityEngine.UI;
using Dressify.Core;

namespace Dressify.Components
{
    /// <summary>
    /// Standard card component — white surface, 20dp radius, shadow level 1.
    /// Attach to any Panel/Image GameObject acting as a card container.
    ///
    /// Inspector setup:
    ///   - CardBackground: Image (set rounded sprite via sliced image)
    ///   - Shadow is achieved via a slightly larger, offset duplicate Image
    ///     underneath with color rgba(0,0,0,0.08) — or use the Unity UI Soft Mask package.
    /// </summary>
    [RequireComponent(typeof(Image))]
    public class DressifyCard : MonoBehaviour
    {
        [Header("Card Settings")]
        [SerializeField] private float  paddingDp    = 16f;
        [SerializeField] private bool   useShadow    = true;
        [SerializeField] private Image  shadowImage;

        private Image _background;

        private void Awake()
        {
            _background = GetComponent<Image>();
            ApplyDesignTokens();
        }

        private void ApplyDesignTokens()
        {
            if (_background != null)
                _background.color = DesignSystem.Instance != null
                    ? DesignSystem.Instance.GetSurface()
                    : Color.white;

            if (useShadow && shadowImage != null)
            {
                // Shadow: rgba(0,0,0,0.08), offset 0 4dp below, spread ~12dp
                // Achieved by a slightly larger image behind the card
                shadowImage.color = new Color(0f, 0f, 0f, 0.08f);
            }
        }

        /// <summary>Refresh colors when theme changes.</summary>
        public void RefreshTheme()
        {
            if (_background != null && DesignSystem.Instance != null)
                _background.color = DesignSystem.Instance.GetSurface();
        }
    }
}
