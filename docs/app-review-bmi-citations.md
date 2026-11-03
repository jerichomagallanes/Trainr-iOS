# BMI citation remediation — October 12, 2026

## Rejection being addressed

App Store Connect submission `5062367c-eb13-4d9b-8059-bff87ae22e6e` was reviewed on October 11, 2026, using an iPad Air 11-inch (M3). The reviewed version was 1.0 (88).

The sole app-version issue shown is guideline 1.4.1: BMI health calculations need citations to their sources, and those citations must be easy to find. The lifetime purchase, subscription group, and monthly/yearly products remain in the submission as Ready for Review; this does not mean Apple has approved them.

The earlier sources sheet is already present on main (`edbf746`, PR #95). Apple's message does not establish why the reviewer missed it. This fix addresses discoverability and makes the relationship between each claim and its source explicit.

## User-visible changes

- Your Measurements always offers **About BMI & sources**, immediately below its introduction, before either measurement is required. This also works when editing saved measurements.
- Every displayed adult BMI result includes its formula and two direct external links: **CDC: BMI calculation** and **CDC: Adult BMI categories**. Users do not have to discover a separate sheet to find citations.
- The sources sheet groups calculation, adult category ranges, and limitations separately, with a relevant CDC link directly after each explanation.
- Source links have at least a 44-point tap target, wrap at larger text sizes, and use Trainr's existing colors and typography. The sheet scrolls and has a Close control.
- The age-20 boundary, measurement validation, calculation, category thresholds, and rounding behavior are unchanged. People below 20 can read the explanation but do not receive an adult BMI number or classification.
- The explanations are bundled for offline reading. External CDC pages require connectivity. No entered measurements or other profile information are included in source URLs.

## Source-to-claim mapping

| Content | Citation |
| --- | --- |
| Kilograms divided by squared height in metres; limitations of BMI | [CDC: About Body Mass Index](https://www.cdc.gov/bmi/about/index.html) |
| Adult age boundary and category ranges | [CDC: Adult BMI Categories](https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html) |
| Review requirement | [Apple App Review Guideline 1.4.1](https://developer.apple.com/app-store/review/guidelines/#1.4.1) |

CDC source pages were checked on October 12, 2026. Trainr first converts imperial measurements into its stored metric units. Its displayed result is rounded to one decimal; the category uses the unrounded value, as explained in the sheet.

## Reviewer navigation for the replacement build

1. Launch Trainr and tap **GET STARTED**.
2. Complete basic information. Use an age of 20 or older to see an adult BMI result.
3. Tap **NEXT** to open **YOUR MEASUREMENTS**.
4. **About BMI & sources** appears below the introduction even before any numbers are entered. Open it to read the methodology, adult ranges, limitations, and linked CDC sources.
5. Close the sheet, enter valid measurements (for example, 175 cm and 72 kg), and scroll below Weight. The BMI result itself shows the formula and direct CDC source links.
6. The same source access is available when reopening Measurements through **Edit** on **YOUR FITNESS PROFILE**. It does not require Pro or a purchase.

## Validation

Checked locally with stable Xcode 26.6 (17F113), with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`:

- Debug build-for-testing and optimized Release simulator build passed.
- All 356 unit tests in 43 suites passed.
- Five targeted UI checks passed on iPhone SE (3rd generation) and iPad Air 11-inch (M3), both running iOS 26.5: sources before inputs, direct result citations, accessibility text, Edit Measurements preserving saved inputs, and adult-result suppression below age 20.
- The result screenshot and accessibility test were rerun after correcting the test's dark-theme launch preference to `-appearance_mode dark`. Screenshots were visually inspected; citations remain reachable by scrolling at accessibility XXXL.
- Strict SwiftLint, UI shard coverage, and `git diff --check` passed.

These are simulator checks, not a signed-device archive or a completed Apple submission. Screenshot fixtures use canned values, not a user's profile. See the retained [review evidence](review-evidence/) and PR for images. The largest-text screenshots intentionally show a scrolled portion of the explanation; all three citation links are checked for reachability. External CDC pages were checked separately; verify they open from the exact replacement archive before submitting.

## Submission steps after merge

1. Build a new Release archive from main after this PR has merged, using the installed non-beta Xcode. Use a build number greater than 88 and any other builds already uploaded to App Store Connect.
2. Install or TestFlight-test that exact build and repeat the reviewer navigation above on iPhone and iPad compatibility mode. Confirm both external CDC destinations open. Retain screenshots of the result and explanation from that exact build.
3. Upload the new archive and wait for processing. Select the new build for version 1.0; do not resubmit build 88 expecting these code changes to appear.
4. Update Notes for Review with the navigation above and attach the new screenshots. Keep the other products attached to this submission unless Apple requests otherwise.
5. Reply to the rejection describing the visible source changes, then resubmit the updated version and its products together.

Suggested reply, to use only after the replacement build and evidence are selected:

> We have made BMI citations directly visible on Your Measurements. About BMI & sources is now available before entering any measurements. After valid measurements are entered for an adult aged 20 or older, the result card itself includes the formula and direct links to the CDC calculation and adult category sources. The explanation groups each claim with its relevant citation and explains limitations. Please see the attached screenshots and the reviewer steps in Notes for Review.

Creating the PR and testing its code does not upload a new build or resubmit the app. App Store approval remains an Apple review decision.
