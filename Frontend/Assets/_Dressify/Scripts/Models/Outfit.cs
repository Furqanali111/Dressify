using System;
using UnityEngine;

namespace Dressify.Models
{
    [Serializable]
    public class Outfit
    {
        public string      Id;
        public string      Name;
        public string      UserId;
        public string      AvatarId;
        public string      ClothingUrl;       // Processed clothing image URL
        public Vector2     Position;          // Final overlay position
        public Vector2     Scale;             // Final overlay scale
        public AiFeedback  AiFeedback;        // May be null if not yet requested
        public long        CreatedAtMs;
    }
}
