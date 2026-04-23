using System.Collections;
using UnityEngine;
using UnityEngine.UI;
using TMPro;
using Dressify.Core;
using Dressify.Models;
using Dressify.Components;

namespace Dressify.Screens
{
    /// <summary>
    /// Screen 3 — Profile Setup
    ///
    /// Inspector setup:
    ///   - NameField: DressifyInputField
    ///   - HeightField: DressifyInputField (numeric)
    ///   - WeightField: DressifyInputField (numeric)
    ///   - BodyTypeChips: ChipGroup (options: Slim/Athletic/Average/Curvy/Plus)
    ///   - UnitToggleHeight: Toggle (cm/ft)
    ///   - UnitToggleWeight: Toggle (kg/lbs)
    ///   - ContinueButton: PrimaryButton
    ///   - SkipLink: Button
    ///   - StepLabel: TextMeshProUGUI "Step 1 of 2"
    /// </summary>
    public class ProfileSetupScreen : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private DressifyInputField nameField;
        [SerializeField] private DressifyInputField heightField;
        [SerializeField] private DressifyInputField weightField;
        [SerializeField] private ChipGroup          bodyTypeChips;
        [SerializeField] private Toggle             metricToggle;   // on = metric
        [SerializeField] private PrimaryButton      continueButton;
        [SerializeField] private Button             skipLink;
        [SerializeField] private TextMeshProUGUI    stepLabel;
        [SerializeField] private TextMeshProUGUI    heightUnitLabel;
        [SerializeField] private TextMeshProUGUI    weightUnitLabel;

        private bool _isMetric = true;

        private void Start()
        {
            if (stepLabel != null) stepLabel.text = "Step 1 of 2";

            // Body type options
            bodyTypeChips?.SetOptions(
                new System.Collections.Generic.List<string>
                { "Slim", "Athletic", "Average", "Curvy", "Plus" },
                defaultIdx: 2
            );

            // Wiring
            if (nameField != null) nameField.OnValueChanged += _ => ValidateForm();
            heightField?.OnEndEdit     += () => ValidateHeight();
            weightField?.OnEndEdit     += () => ValidateWeight();

            metricToggle?.onValueChanged.AddListener(OnUnitToggle);

            continueButton?.OnClick += HandleContinue;
            skipLink?.onClick.AddListener(HandleSkip);

            continueButton?.SetInteractable(false);
            UpdateUnitLabels();
        }

        // ── Validation ────────────────────────────────────────────────────────────

        private void ValidateForm()
        {
            bool nameOk = !string.IsNullOrEmpty(nameField?.Value);
            continueButton?.SetInteractable(nameOk);
        }

        private void ValidateHeight()
        {
            if (!float.TryParse(heightField?.Value, out float val)) return;
            float min = _isMetric ? 100f : 39f;
            float max = _isMetric ? 250f : 98f;
            if (val < min || val > max)
                heightField?.ShowError(Strings.ErrorHeightRange);
            else
                heightField?.ClearError();
        }

        private void ValidateWeight()
        {
            if (!float.TryParse(weightField?.Value, out float val)) return;
            float min = _isMetric ? 30f  : 66f;
            float max = _isMetric ? 300f : 660f;
            if (val < min || val > max)
                weightField?.ShowError(Strings.ErrorWeightRange);
            else
                weightField?.ClearError();
        }

        // ── Unit Toggle ───────────────────────────────────────────────────────────

        private void OnUnitToggle(bool isOn)
        {
            _isMetric = isOn;
            UpdateUnitLabels();
        }

        private void UpdateUnitLabels()
        {
            if (heightUnitLabel != null) heightUnitLabel.text = _isMetric ? "cm"  : "ft";
            if (weightUnitLabel != null) weightUnitLabel.text = _isMetric ? "kg"  : "lbs";
        }

        // ── Continue / Skip ───────────────────────────────────────────────────────

        private void HandleContinue()
        {
            ValidateHeight();
            ValidateWeight();

            var profile = AppManager.Instance.CurrentUser ?? new UserProfile();
            profile.Name     = nameField?.Value;
            profile.IsMetric = _isMetric;

            if (float.TryParse(heightField?.Value, out float h))
                profile.HeightCm = _isMetric ? h : h * 30.48f;
            if (float.TryParse(weightField?.Value, out float w))
                profile.WeightKg = _isMetric ? w : w * 0.453592f;

            int bodyIdx = bodyTypeChips?.GetSelectedIndex() ?? 2;
            profile.BodyType = (BodyType)bodyIdx;

            AppManager.Instance.CurrentUser = profile;
            NavigationManager.Instance.Push(NavigationManager.Scenes.AvatarSelect);
        }

        private void HandleSkip() =>
            NavigationManager.Instance.Push(NavigationManager.Scenes.AvatarSelect);
    }
}
