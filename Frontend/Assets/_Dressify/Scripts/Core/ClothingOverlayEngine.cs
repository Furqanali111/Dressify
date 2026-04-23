using UnityEngine;
using Dressify.Models;

namespace Dressify.Core
{
    /// <summary>
    /// Positions and scales the clothing RectTransform on the avatar canvas
    /// using anchor points returned by the FastAPI backend.
    ///
    /// Coordinate system assumption:
    ///   - Avatar canvas is the parent RectTransform (full height)
    ///   - anchor_points are normalized (0–1) relative to the original image
    ///   - Avatar anchor maps define where each avatar's shoulder/chest/waist are
    ///     in local canvas coordinates.
    /// </summary>
    public static class ClothingOverlayEngine
    {
        // ── Avatar anchor maps (canvas local coords, normalized 0–1) ─────────────
        // These match your avatar artwork. Adjust per avatar illustration.
        private static readonly AvatarAnchors[] AvatarAnchorMaps =
        {
            // Slim
            new AvatarAnchors { Shoulder = new Vector2(0.5f, 0.72f), Chest = new Vector2(0.5f, 0.60f), Waist = new Vector2(0.5f, 0.48f) },
            // Athletic
            new AvatarAnchors { Shoulder = new Vector2(0.5f, 0.73f), Chest = new Vector2(0.5f, 0.61f), Waist = new Vector2(0.5f, 0.49f) },
            // Average
            new AvatarAnchors { Shoulder = new Vector2(0.5f, 0.74f), Chest = new Vector2(0.5f, 0.62f), Waist = new Vector2(0.5f, 0.50f) },
            // Curvy
            new AvatarAnchors { Shoulder = new Vector2(0.5f, 0.73f), Chest = new Vector2(0.5f, 0.61f), Waist = new Vector2(0.5f, 0.47f) },
            // Plus
            new AvatarAnchors { Shoulder = new Vector2(0.5f, 0.72f), Chest = new Vector2(0.5f, 0.60f), Waist = new Vector2(0.5f, 0.46f) }
        };

        /// <summary>
        /// Apply clothing overlay to the given RectTransform.
        /// </summary>
        /// <param name="clothingRt">The clothing image RectTransform to reposition.</param>
        /// <param name="avatarRt">The avatar's RectTransform (reference coordinate space).</param>
        /// <param name="apiAnchors">Anchor points received from the backend.</param>
        /// <param name="avatarType">Currently selected avatar type.</param>
        public static void ApplyOverlay(
            RectTransform clothingRt,
            RectTransform avatarRt,
            AnchorPoints apiAnchors,
            AvatarType avatarType)
        {
            if (clothingRt == null || avatarRt == null || apiAnchors == null) return;

            int idx = (int)avatarType;
            if (idx < 0 || idx >= AvatarAnchorMaps.Length) idx = 2;

            var avatarMap = AvatarAnchorMaps[idx];
            var canvasSize = avatarRt.rect.size;

            // Map avatar shoulder anchor to canvas pixel position
            Vector2 avatarShoulderPx = new Vector2(
                avatarMap.Shoulder.x * canvasSize.x,
                avatarMap.Shoulder.y * canvasSize.y
            );

            // Map API anchor to canvas pixel space
            // API gives clothing shoulder in clothing-image normalized coords.
            // We use the avatar canvas size as reference for clothing placement.
            Vector2 clothingShoulderLocal = new Vector2(
                apiAnchors.Shoulder.x * canvasSize.x,
                apiAnchors.Shoulder.y * canvasSize.y
            );

            // Translate clothing so its shoulder aligns with avatar's shoulder
            Vector2 offset = avatarShoulderPx - clothingShoulderLocal;

            // Compute scale from waist-to-shoulder distance
            float apiHeight    = Mathf.Abs(apiAnchors.Waist.y - apiAnchors.Shoulder.y) * canvasSize.y;
            float avatarHeight = Mathf.Abs(avatarMap.Waist.y  - avatarMap.Shoulder.y)  * canvasSize.y;
            float scale = (apiHeight > 0.001f) ? (avatarHeight / apiHeight) : 1f;
            scale = Mathf.Clamp(scale, 0.5f, 2.5f);

            // Apply
            clothingRt.anchoredPosition = offset;
            clothingRt.localScale       = Vector3.one * scale;
        }

        // ── Helper type ───────────────────────────────────────────────────────────
        private struct AvatarAnchors
        {
            public Vector2 Shoulder;
            public Vector2 Chest;
            public Vector2 Waist;
        }
    }
}
