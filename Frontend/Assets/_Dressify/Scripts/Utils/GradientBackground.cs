using UnityEngine;
using UnityEngine.UI;

namespace Dressify.Utils
{
    /// <summary>
    /// Renders a two-stop linear gradient on a UI Image by tinting vertex colors.
    /// Used for the Splash background (primary → soft lavender).
    ///
    /// Inspector:
    ///   - TopColor / BottomColor: the two gradient stops
    ///   - Direction: Vertical (default) or Horizontal
    ///
    /// Requires the Image to use a white 1×1 pixel sprite.
    /// </summary>
    [RequireComponent(typeof(Image))]
    public class GradientBackground : BaseMeshEffect
    {
        public enum GradientDir { Vertical, Horizontal }

        [Header("Gradient")]
        public Color       topColor    = new Color(0.424f, 0.388f, 1.000f); // #6C63FF
        public Color       bottomColor = new Color(0.769f, 0.710f, 0.992f); // #C4B5FD
        public GradientDir direction   = GradientDir.Vertical;

        public override void ModifyMesh(VertexHelper vh)
        {
            if (!IsActive()) return;

            var verts = new System.Collections.Generic.List<UIVertex>();
            vh.GetUIVertexStream(verts);

            // Find bounding box
            float minY = float.MaxValue, maxY = float.MinValue;
            float minX = float.MaxValue, maxX = float.MinValue;
            foreach (var v in verts)
            {
                minY = Mathf.Min(minY, v.position.y);
                maxY = Mathf.Max(maxY, v.position.y);
                minX = Mathf.Min(minX, v.position.x);
                maxX = Mathf.Max(maxX, v.position.x);
            }

            float range = direction == GradientDir.Vertical
                ? (maxY - minY)
                : (maxX - minX);
            if (range <= 0f) return;

            for (int i = 0; i < verts.Count; i++)
            {
                var vert = verts[i];
                float t = direction == GradientDir.Vertical
                    ? (vert.position.y - minY) / range
                    : (vert.position.x - minX) / range;

                // top = t=1, bottom = t=0
                vert.color = Color.Lerp(bottomColor, topColor, t);
                verts[i]   = vert;
            }

            vh.Clear();
            vh.AddUIVertexTriangleStream(verts);
        }
    }
}
