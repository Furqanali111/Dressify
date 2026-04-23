using System.Collections;
using UnityEngine;
using UnityEngine.UI;

namespace Dressify.Utils
{
    /// <summary>
    /// Simple confetti burst particle effect for the "Outfit Saved" moment.
    /// Spawns colored rect particles that arc up and fall with gravity.
    ///
    /// Inspector:
    ///   - ParticleContainer: RectTransform to parent particles into (Canvas space)
    ///   - spawn the prefab or use a simple Coroutine approach (implemented here)
    /// </summary>
    public class ConfettiBurst : MonoBehaviour
    {
        public static ConfettiBurst Instance { get; private set; }

        [SerializeField] private RectTransform particleContainer;
        [SerializeField] private int           particleCount = 40;
        [SerializeField] private float         burstDuration = 0.5f;

        private static readonly Color[] Colors =
        {
            new Color(0.424f, 0.388f, 1f),    // primary purple
            new Color(0.133f, 0.788f, 0.478f), // green
            new Color(1f,     0.757f, 0.027f), // amber
            new Color(1f,     0.361f, 0.361f), // red
            new Color(0.259f, 0.522f, 0.957f)  // blue
        };

        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        public void Burst(Vector2 originScreen)
        {
            StartCoroutine(BurstRoutine(originScreen));
        }

        private IEnumerator BurstRoutine(Vector2 origin)
        {
            if (particleContainer == null) yield break;

            var particles = new RectTransform[particleCount];

            for (int i = 0; i < particleCount; i++)
            {
                var go   = new GameObject($"confetti_{i}", typeof(Image));
                go.transform.SetParent(particleContainer, false);
                var img  = go.GetComponent<Image>();
                var rt   = go.GetComponent<RectTransform>();

                img.color  = Colors[i % Colors.Length];
                rt.sizeDelta = new Vector2(
                    Random.Range(6f, 12f),
                    Random.Range(8f, 16f)
                );
                rt.position = origin;
                rt.rotation = Quaternion.Euler(0, 0, Random.Range(0f, 360f));
                particles[i] = rt;
            }

            // Animate
            float elapsed = 0f;
            var velocities = new Vector2[particleCount];
            for (int i = 0; i < particleCount; i++)
                velocities[i] = new Vector2(
                    Random.Range(-400f, 400f),
                    Random.Range(300f, 700f)
                );

            while (elapsed < burstDuration + 0.5f)
            {
                elapsed += Time.deltaTime;
                float alpha = 1f - Mathf.Clamp01((elapsed - burstDuration) / 0.5f);

                for (int i = 0; i < particleCount; i++)
                {
                    if (particles[i] == null) continue;
                    velocities[i].y -= 1200f * Time.deltaTime; // gravity
                    particles[i].position += (Vector3)(velocities[i] * Time.deltaTime);
                    particles[i].Rotate(0, 0, Random.Range(-180f, 180f) * Time.deltaTime);

                    var img = particles[i].GetComponent<Image>();
                    if (img != null)
                    {
                        var c = img.color;
                        c.a = alpha;
                        img.color = c;
                    }
                }
                yield return null;
            }

            foreach (var p in particles)
                if (p != null) Destroy(p.gameObject);
        }
    }
}
