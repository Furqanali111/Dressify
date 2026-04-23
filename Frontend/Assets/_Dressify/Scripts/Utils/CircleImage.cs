using UnityEngine;
using UnityEngine.UI;

namespace Dressify.Utils
{
    /// <summary>
    /// Makes a UI Image circular by setting a circle sprite mask.
    /// Useful for avatar thumbnails and icon buttons.
    ///
    /// Inspector: attach to the Image GameObject. Radius is set by the RectTransform size.
    /// </summary>
    [RequireComponent(typeof(Image))]
    public class CircleImage : MonoBehaviour
    {
        private void Awake()
        {
            var img = GetComponent<Image>();
            if (img != null) img.preserveAspect = true;

            // Add a mask so child content is also clipped
            var mask = gameObject.GetComponent<Mask>() ?? gameObject.AddComponent<Mask>();
            mask.showMaskGraphic = true;
        }
    }
}
