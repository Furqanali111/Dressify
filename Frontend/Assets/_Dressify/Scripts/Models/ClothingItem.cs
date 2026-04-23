using System;
using UnityEngine;

namespace Dressify.Models
{
    public enum ClothingType { Top, Bottom, Dress, Jacket, Other }

    [Serializable]
    public class ClothingItem
    {
        public string       Id;
        public string       Name;
        public ClothingType Type;
        public string       OriginalImageUrl;
        public string       ProcessedImageUrl;  // PNG with transparent background
        public AnchorPoints AnchorPoints;
        public float        ConfidenceScore;    // 0–1
        public string       UserId;
        public long         CreatedAtMs;

        // Computed
        public bool IsLowConfidence => ConfidenceScore < 0.7f;
    }

    [Serializable]
    public class AnchorPoints
    {
        public Vector2 Shoulder;
        public Vector2 Chest;
        public Vector2 Waist;
    }
}
