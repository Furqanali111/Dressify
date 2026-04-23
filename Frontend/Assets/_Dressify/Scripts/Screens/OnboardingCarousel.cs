using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;

namespace Dressify.Screens
{
    /// <summary>
    /// Screen 1b — Onboarding Carousel (first-launch only)
    ///
    /// Inspector setup:
    ///   - SlideContainer: RectTransform (horizontal layout, 3 slide children)
    ///   - Dots[0..2]: Images for progress indicators
    ///   - SkipButton: Button (hidden on slide 3)
    ///   - NextButton / GetStartedButton: toggle on last slide
    ///   - Each slide: Illustration Image + TitleLabel + DescLabel
    /// </summary>
    public class OnboardingCarousel : MonoBehaviour
    {
        [Header("Slides")]
        [SerializeField] private RectTransform slideContainer;
        [SerializeField] private float         slideWidth = 1080f;

        [Header("Slide Content")]
        [SerializeField] private Image[]           illustrations = new Image[3];
        [SerializeField] private TextMeshProUGUI[] titles        = new TextMeshProUGUI[3];
        [SerializeField] private TextMeshProUGUI[] descriptions  = new TextMeshProUGUI[3];

        [Header("Controls")]
        [SerializeField] private Button          skipButton;
        [SerializeField] private Button          nextButton;
        [SerializeField] private Button          getStartedButton;
        [SerializeField] private TextMeshProUGUI nextButtonLabel;

        [Header("Dots")]
        [SerializeField] private Image[] dots = new Image[3];
        [SerializeField] private Color   dotActive   = new Color(0.424f, 0.388f, 1f);
        [SerializeField] private Color   dotInactive = new Color(0.80f, 0.80f, 0.85f);

        private int       _currentSlide = 0;
        private bool      _isAnimating  = false;

        private static readonly string[] Titles = {
            Strings.Onboard1Title,
            Strings.Onboard2Title,
            Strings.Onboard3Title
        };
        private static readonly string[] Descs = {
            Strings.Onboard1Desc,
            Strings.Onboard2Desc,
            Strings.Onboard3Desc
        };

        private void Start()
        {
            // Populate labels
            for (int i = 0; i < 3; i++)
            {
                if (titles[i] != null)       titles[i].text       = Titles[i];
                if (descriptions[i] != null) descriptions[i].text = Descs[i];
            }

            skipButton?.onClick.AddListener(GoToSignIn);
            nextButton?.onClick.AddListener(NextSlide);
            getStartedButton?.onClick.AddListener(GoToSignIn);

            RefreshDots();
            RefreshButtons();
        }

        // ── Navigation ────────────────────────────────────────────────────────────

        private void NextSlide()
        {
            if (_isAnimating || _currentSlide >= 2) return;
            _currentSlide++;
            StartCoroutine(SlideTransition());
        }

        // Swipe support
        private Vector2 _swipeStart;

        private void Update()
        {
            if (Input.touchCount <= 0) return;
            var touch = Input.GetTouch(0);
            if (touch.phase == TouchPhase.Began)  _swipeStart = touch.position;
            if (touch.phase == TouchPhase.Ended   && !_isAnimating)
            {
                float delta = _swipeStart.x - touch.position.x;
                if (Mathf.Abs(delta) > 80f)
                {
                    if (delta > 0 && _currentSlide < 2) { _currentSlide++; StartCoroutine(SlideTransition()); }
                    if (delta < 0 && _currentSlide > 0) { _currentSlide--; StartCoroutine(SlideTransition()); }
                }
            }
        }

        private IEnumerator SlideTransition()
        {
            _isAnimating = true;
            float targetX = -_currentSlide * slideWidth;
            float startX  = slideContainer.anchoredPosition.x;
            float dur = 0.3f, elapsed = 0f;

            while (elapsed < dur)
            {
                elapsed += Time.deltaTime;
                float t = TweenHelper.EaseInOut(Mathf.Clamp01(elapsed / dur));
                var pos = slideContainer.anchoredPosition;
                pos.x = Mathf.Lerp(startX, targetX, t);
                slideContainer.anchoredPosition = pos;
                yield return null;
            }
            var finalPos = slideContainer.anchoredPosition;
            finalPos.x = targetX;
            slideContainer.anchoredPosition = finalPos;

            RefreshDots();
            RefreshButtons();
            _isAnimating = false;
        }

        private void RefreshDots()
        {
            for (int i = 0; i < dots.Length; i++)
                if (dots[i] != null)
                    dots[i].color = i == _currentSlide ? dotActive : dotInactive;
        }

        private void RefreshButtons()
        {
            bool isLast = _currentSlide == 2;
            if (skipButton != null)        skipButton.gameObject.SetActive(!isLast);
            if (nextButton != null)        nextButton.gameObject.SetActive(!isLast);
            if (getStartedButton != null)  getStartedButton.gameObject.SetActive(isLast);
        }

        private void GoToSignIn() =>
            NavigationManager.Instance.NavigateToRoot(NavigationManager.Scenes.SignIn);
    }
}
