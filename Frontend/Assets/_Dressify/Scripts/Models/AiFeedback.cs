using System;
using System.Collections.Generic;

namespace Dressify.Models
{
    [Serializable]
    public class AiFeedback
    {
        public string             OutfitId;
        public float              Score;        // 0–10
        public string             Verdict;      // e.g. "Great casual look! ✨"
        public List<Suggestion>   Suggestions;
    }

    [Serializable]
    public class Suggestion
    {
        public string Category;    // "Color harmony", "Style balance", etc.
        public string IconName;    // Material symbol name e.g. "palette"
        public string Text;
        public string ColorHex;    // Category accent color
    }
}
