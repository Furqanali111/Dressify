using System;
using UnityEngine;

namespace Dressify.Models
{
    [Serializable]
    public class UserProfile
    {
        public string Uid;
        public string Name;
        public string Email;
        public string PhotoUrl;

        // Body attributes
        public float  HeightCm;
        public float  WeightKg;
        public BodyType BodyType;

        // Preferences
        public bool   IsMetric = true;      // cm/kg vs ft/lbs
        public string Theme    = "system";  // "light" | "dark" | "system"
    }

    public enum BodyType { Slim, Athletic, Average, Curvy, Plus }
}
