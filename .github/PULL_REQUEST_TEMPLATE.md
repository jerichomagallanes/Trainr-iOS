## What this changes

<!-- One or two sentences. What does the app do now that it didn't before? -->

## Why

<!-- The reason for the change: the bug, the feature, the cleanup.
     Link the issue if there is one, e.g. "Closes #12". -->

## How it works

<!-- The approach, and anything a reader would otherwise have to reverse
     engineer from the diff. Note any alternative you rejected and why. -->

## Out of scope

<!-- Anything deliberately left for a follow-up, so future-you knows it was a
     decision and not an oversight. Delete this section if nothing applies. -->

## How to verify

<!-- Steps someone can follow: screen -> action -> expected result. -->

1.

## Screenshots / recording

<!-- Required for any user-visible change. Before/after side by side is ideal.

| Before | After |
| --- | --- |
| <img src="" width="300" /> | <img src="" width="300" /> |
-->

---

## Self-review checklist

<!-- Go through the "Files changed" tab before merging and tick these off. -->

- [ ] I read the full diff in the "Files changed" tab as if it were someone else's code
- [ ] No leftover debug logging, commented-out code, or `TODO`s I meant to finish
- [ ] No secrets, API keys, `GoogleService-Info.plist`, or personal data in the diff
- [ ] Unit tests cover the new behaviour, and existing tests still pass
- [ ] Strings live in `Localizable.xcstrings` and are read through `L10n`, never typed inline in a view
- [ ] Checked in both light and dark mode, and with a larger Dynamic Type size
- [ ] The change is scoped to one thing — anything unrelated belongs in its own PR
