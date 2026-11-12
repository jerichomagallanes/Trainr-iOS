# Release secrets and the release branches (iOS)

Everything the two release workflows need, and nothing they can create for
themselves. The Android repository has its own copy of this document covering
the Play half; the two are deliberately separate, because the secrets are.

Until every secret below exists, both workflows stop on their first step and
name the one that is missing. They never half-run.

## The branches

- `version/X.Y` is the release's work in progress. Fix and feature branches
  merge into it, it is allowed to be noisy, and it produces no store build.
- `pre-release` is permanent and not per version. Merging `version/X.Y` into it
  is the signal that a candidate is worth testing: that one push archives the
  app, uploads it to TestFlight, and stops.
- There is no release branch. Production is reached by running **Promote to
  production** against a build number that is already on TestFlight.
- After a release ships, `version/X.Y` merges into `main` for the record and the
  release is tagged there.

Create it once:

```sh
git fetch origin
git switch -c pre-release origin/main
git push -u origin pre-release
```

Bring it forward afterwards. `main` moves by squash merge, so `pre-release`
cannot fast-forward to it; merge it in rather than resetting, so the branch keeps
one history across releases. If the squash commit conflicts, keep what
`pre-release` already has — it is the same work, arriving a second time. Do this
in the same push as the next candidate, so the release line still gets exactly
one build per candidate rather than one for the merge and another for the
candidate:

```sh
git fetch origin
git switch pre-release
git merge --no-ff origin/main
git merge --no-ff origin/version/2.1
git push origin pre-release
```

## The production environment

**Settings → Environments → New environment → `production`**, then tick
**Required reviewers** and add yourself. The promotion job does not start, and
never sees the API key, until someone approves it there, and GitHub keeps the
record of who did. Required reviewers are free on a public repository.

## The secrets

All of these go in **Settings → Secrets and variables → Actions → New
repository secret**, with the name spelled exactly as below.

### `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_BASE64`

One key, three fields. It replaces a distribution certificate and a provisioning
profile: `xcodebuild -allowProvisioningUpdates` uses it to issue both onto a
runner that has neither, and fastlane uses it to upload and to submit.

App Store Connect → **Users and Access → Integrations → App Store Connect API →
Team Keys** → **Generate API Key**. Name it `trainr-release` and give it the
**App Manager** role — **Developer** cannot submit for review.

- `APP_STORE_CONNECT_ISSUER_ID` — the **Issuer ID** printed above the table on
  that page. One per team; it does not change.
- `APP_STORE_CONNECT_KEY_ID` — the **Key ID** column of the row you just made.
- `APP_STORE_CONNECT_KEY_BASE64` — the `.p8` file, which downloads **once** and
  cannot be downloaded again:

  ```sh
  base64 -i ~/Downloads/AuthKey_<KEY_ID>.p8 | pbcopy
  ```

Delete the downloaded `.p8` afterwards. A new key can always be generated; this
one cannot be read back.

### `GOOGLE_SERVICE_INFO_PLIST`

The whole contents of `Trainr/Resources/GoogleService-Info.plist`, pasted as it
is — raw XML, not base64. The file is gitignored, so CI has no other way to get
it, and without it the shipped app skips `FirebaseApp.configure()` and the
archive uploads no symbols: a release with no crash reporting at all, arrived at
without a single error.

```sh
pbcopy < Trainr/Resources/GoogleService-Info.plist
```

Firebase console → **Project settings → Your apps → Trainr (iOS) →
GoogleService-Info.plist** if you need to download it again.

## The variable

**Settings → Secrets and variables → Actions → Variables → New repository
variable.** A variable rather than a secret, because it is not one.

### `MARKETING_VERSION`

The version a candidate carries: `1.1`, `2.0`, `1.0.2`. The build workflow
passes it to `xcodebuild` on the command line, so the project file is never
edited to make a release — the `MARKETING_VERSION` committed in
`Trainr.xcodeproj` is stale and is not the source of truth.

Change it here the moment a release line starts a new version, before the first
candidate of that version is built, and set Android's `versionName` in
`app/build.gradle.kts` to the same string in the same sitting. It is the one
number the two stores must agree on for one release of one product, and nothing
links or checks them. The workflow stops if it is unset or does not look like a
version number, but it cannot tell that you forgot to bump it.

## Two settings in App Store Connect

Neither is a secret, and neither can be done from a workflow.

**Once**, so a candidate actually reaches testers: App Store Connect →
**TestFlight → Internal Testing** → your group → enable **Automatically
distribute builds**. The build workflow uploads and stops; App Store Connect
hands the finished build to the group.

**Before each promotion**, because the promotion never writes metadata: App
Store Connect → **Distribution** → the iOS App version → create the version
matching `MARKETING_VERSION` and fill in **What's New in This Version**. Leave
the build empty. **Promote to production** selects the build you name, attaches
it to that version and submits it; it stops with "could not find an editable
version" if nobody prepared one, and it will never overwrite the text you wrote.
