using System;
using System.Collections.Generic;

namespace Dressify.Models
{
    // ── Generic wrapper ──────────────────────────────────────────────────────────

    [Serializable]
    public class ApiResponse<T>
    {
        public bool   Success;
        public string Message;
        public T      Data;
        public string ErrorCode;
    }

    // ── Upload ───────────────────────────────────────────────────────────────────

    [Serializable]
    public class UploadResponse
    {
        public string       processed_image_url;
        public string       clothing_type;
        public float        confidence_score;
        public AnchorPoints anchor_points;
        public string       item_id;
    }

    // ── Save Outfit ───────────────────────────────────────────────────────────────

    [Serializable]
    public class SaveOutfitRequest
    {
        public string   user_id;
        public string   avatar_id;
        public string   clothing_url;
        public float[]  position;     // [x, y]
        public float[]  scale;        // [x, y]
        public string   ai_feedback_json;
    }

    [Serializable]
    public class SaveOutfitResponse
    {
        public string outfit_id;
    }

    // ── AI Feedback ───────────────────────────────────────────────────────────────

    [Serializable]
    public class FeedbackRequest
    {
        public string user_id;
        public string outfit_id;
        public string avatar_type;
        public string clothing_type;
    }

    [Serializable]
    public class FeedbackResponse
    {
        public float                score;
        public string               verdict;
        public List<FeedbackSuggestionRaw> suggestions;
    }

    [Serializable]
    public class FeedbackSuggestionRaw
    {
        public string category;
        public string text;
        public string icon;
        public string color;
    }

    // ── Wardrobe ──────────────────────────────────────────────────────────────────

    [Serializable]
    public class WardrobeResponse
    {
        public List<ClothingItem> clothing_items;
        public List<Outfit>       saved_outfits;
    }
}
