# App Review remediation — 1.0, October 2026

Apple rejected build 87 on October 1. This change addresses the app-side issues:

- Measurements → About BMI & sources opens a readable explanation and two CDC links.
  CDC adult categories are shown only for ages 20+, using the age already entered
  on the preceding onboarding step. Editing measurements uses the current profile age.
- UMP regional consent runs before explicit ATT. ATT is requested only while active,
  only when undetermined, and before Mobile Ads starts. Denied/restricted users can
  proceed without IDFA. Foreground activation retries a launch without a ready scene.
- Restoring purchases no longer reports network failures as “nothing to restore”.
  Purchases distinguish cancellation, pending approval and failures. Free-trial copy
  requires both a free-trial offer and confirmed account eligibility from RevenueCat.
- The app-owned privacy manifest no longer declares fitness data sent to Gemini.
  Planning is local. Tracking is declared for AdMob's documented ad-request domain,
  `googleads.g.doubleclick.net`. SDK manifests remain bundled and must be considered
  alongside the app manifest and App Store privacy declarations. A denied ATT choice
  may block requests to that domain; workout features remain available without ads.

Companion changes in the Android/shared website repository update the string source,
privacy policy, promotional text and original closing screenshot artwork. Publish
that policy before resubmitting. Product IDs and entitlement remain unchanged.

## Review walkthrough

1. Fresh install on a physical iPhone/iPad with tracking requests allowed and no
   previous decision for Trainr. Record launch, any regional consent, ATT and the
   next screen. Declining tracking must still allow onboarding and workout logging.
2. Welcome → Get started → enter age 20 or older → Measurements → valid height and
   weight → About BMI & sources. Repeat with age 19: no adult BMI classification.
3. Complete onboarding → profile menu → Trainr Pro. Verify monthly, annual upfront
   and lifetime, current localized prices, Restore purchases and Terms/Privacy links.
4. Test purchases and restore with StoreKit sandbox, including cancellation,
   temporary network failure and an existing subscriber. Do not use production
   payment transactions as review tests.

## Submission requirements outside this source change

- Replace pricing artwork in every relevant screenshot size/localization; inspect
  inherited images. Use the companion generator and assets.
- Include monthly, yearly and lifetime products with the new app version. Each
  needs its actual paywall review screenshot, complete localization and availability.
- Keep monthly and yearly at the same service level because both grant the same Pro.
- Confirm RevenueCat's current offering packages map to the three existing products
  and entitlement `trainr_workout_planner_pro`.
- Attach the physical-device ATT recording and reference its actual filename/link in
  App Review Notes. Do not claim a recording or purchase test exists before it does.
- Archive with `/Applications/Xcode.app` (stable Xcode), assign a new build number
  greater than 87, and verify the exported archive's SDK and version before upload.
- Select the processed new build, submit the products and version together, and keep
  the existing manual-release setting.

## Sources

- https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html
- https://www.cdc.gov/bmi/about/index.html
- https://developers.google.com/admob/ios/privacy
- https://developers.google.com/admob/ios/privacy/idfa
- https://developers.google.com/admob/ios/privacy/data-disclosure
- https://support.google.com/admob/answer/7671795
- https://developer.apple.com/documentation/technotes/tn3182-adding-privacy-tracking-keys-to-your-privacy-manifest
- https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy
- https://developer.apple.com/app-store/review/guidelines/

## Privacy disclosure audit

The Release archive bundles Google Mobile Ads 13.9, UMP, Firebase Crashlytics and
RevenueCat manifests. Their declared collection is the baseline for App Store
Connect, even though Trainr's workout profile itself stays on the device:

| Data | Linked to identity | Tracking | Purposes |
| --- | --- | --- | --- |
| Device ID | Yes | Yes | Third-party advertising, developer advertising, analytics |
| Coarse location | Yes | No | Third-party advertising, developer advertising, analytics |
| Product interaction | Yes | No | Third-party advertising, developer advertising, analytics |
| Advertising data | Yes | No in SDK manifest | Third-party advertising, developer advertising, analytics |
| Performance data | No | No | Third-party advertising, developer advertising, analytics |
| Crash data | No | No | Analytics, app functionality |
| Other diagnostic data | No | No | Third-party advertising, developer advertising, analytics, app functionality |
| Purchase history | No (anonymous RevenueCat IDs) | No | Analytics, app functionality |

The existing App Store label also discloses advertising data for tracking. Keep
that conservative disclosure unless the configured advertising behavior is audited
more narrowly. No fitness measurements are passed to these SDKs by Trainr. Reaudit
domains and data when adding mediation, attribution integrations or SDK versions.
