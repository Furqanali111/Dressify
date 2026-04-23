using System.Collections.Generic;
using UnityEngine;
using Dressify.Core;

namespace Dressify.Utils
{
    /// <summary>
    /// Global theme manager. Broadcasts theme changes to all registered ThemeTarget
    /// components in the scene so they can update their colors.
    ///
    /// Usage: ThemeManager.SetTheme(ThemeMode.Dark);
    /// </summary>
    public static class ThemeManager
    {
        private static ThemeMode _current = ThemeMode.System;
        private static readonly List<System.WeakReference<IThemeTarget>> _targets = new();

        public static ThemeMode Current => _current;

        public static void SetTheme(ThemeMode mode)
        {
            _current = mode;
            bool dark = mode == ThemeMode.Dark ||
                        (mode == ThemeMode.System && IsSystemDark());
            DesignSystem.SetDarkMode(dark);
            NotifyAll();
        }

        public static void Register(IThemeTarget t) =>
            _targets.Add(new System.WeakReference<IThemeTarget>(t));

        private static void NotifyAll()
        {
            _targets.RemoveAll(wr => !wr.TryGetTarget(out _));
            foreach (var wr in _targets)
            {
                if (wr.TryGetTarget(out var t)) t.OnThemeChanged(_current);
            }
        }

        private static bool IsSystemDark()
        {
            // Unity doesn't expose system dark mode directly until 2022+
            // On Android use: new AndroidJavaClass("android.os.Build$VERSION_CODES")
            // For MVP always returns false (light mode default)
            return false;
        }
    }

    public enum ThemeMode { System, Light, Dark }

    public interface IThemeTarget
    {
        void OnThemeChanged(ThemeMode mode);
    }
}
