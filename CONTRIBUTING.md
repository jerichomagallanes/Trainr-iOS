# Contributing to Trainr for iOS

Trainr is a solo project, but it is developed as though it weren't. Every change
reaches `main` through a pull request that has passed CI and a deliberate
self-review. The point isn't ceremony — it's that reviewing your own diff in a
separate context catches the debug log you forgot to delete, the hardcoded
string, and the half-finished branch of an `if`, well before they become
history.

This repository follows the Android app's conventions, so the two read as one
project. Where a rule differs, it is because the platform differs.

---

## The workflow

### 1. Branch

`main` is protected: it accepts no direct pushes. Start from an up-to-date copy:

```bash
git switch main
git pull
git switch -c feat/workout-timer
```

Branch names are `<type>/<short-description>`, using the same types as commits:

| Prefix      | For                                             |
| ----------- | ----------------------------------------------- |
| `feat/`     | A new capability                                |
| `fix/`      | A bug fix                                       |
| `refactor/` | Restructuring with no behaviour change          |
| `test/`     | Tests only                                      |
| `docs/`     | Documentation only                              |
| `chore/`    | Build, tooling, dependencies                    |

### 2. Commit

Commits follow [Conventional Commits](https://www.conventionalcommits.org):
`<type>(<optional scope>): <imperative summary>`.

```
feat(workout): add rest-day preference step
fix(store): stop losing body metrics on locale change
```

**One short sentence, and nothing more.** No body, no trailers, no co-authors.
Describe *what changes*, not what you did, and keep it under ~72 characters. The
reasoning belongs in the PR description, where it stays readable — not spread
across a commit body that nobody reads again.

Scopes follow the source tree: `onboarding`, `workout`, `generation`, `store`,
`design`, `ci`, `deps`.

### 3. Open a draft PR early

Push and open the PR as soon as you have your first commit — not when you're
finished:

```bash
git push -u origin feat/workout-timer
gh pr create --draft --fill
```

An early draft gives you CI on every push and a place to think out loud while
the work is still malleable. Fill in the template as you go rather than
reconstructing it at the end.

### 4. Let CI run

Every PR runs three required checks and two advisory ones:

| Check                    | What it does                                                  | Blocks merge |
| ------------------------ | ------------------------------------------------------------- | ------------ |
| **Unit tests**           | Swift Testing suites, annotated per failing test on the diff   | Yes |
| **SwiftLint**            | `--strict`, findings published to the Security tab             | Yes |
| **Build app**            | A Debug build for the simulator                                | Yes |
| **UI tests**             | XCUITest on a simulator                                        | No |
| **Release smoke**        | Builds Release and checks it launches without crashing         | No |

UI tests are advisory on purpose: simulators flake, and a flake should never be
the reason a correct change can't merge. Read the result, re-run if it looks
like an infrastructure failure, and investigate if it doesn't. They also run
nightly against `main`.

Every run needs a macOS runner, and a push starts five of them at once — which
is the free concurrency limit. Expect a queue, and don't push more often than
you have to.

### 5. Self-review, then merge

Mark the PR ready, then **open the "Files changed" tab and read the whole diff**
before merging. Work through the checklist in the PR template — it exists
because the things it lists are the things that actually slip through.

Merge with **Squash and merge** (the only option enabled). The PR title becomes
the commit message on `main`, so it must read as a good commit: same
Conventional Commits format, same one-sentence limit. The branch deletes itself
on merge.

---

## Running things locally

The simulator is named `iPhone 17 Pro 27`. The stock iPhone 17 simulators run
iOS 26.2, which crashes SwiftData built against the iOS 27 SDK.

```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro 27'

# Unit tests
xcodebuild test -project Trainr.xcodeproj -scheme Trainr \
  -destination "$DEST" -only-testing:TrainrTests

# SwiftLint, exactly as CI runs it
swiftlint lint --strict

# UI tests
xcodebuild test -project Trainr.xcodeproj -scheme Trainr \
  -destination "$DEST" -only-testing:TrainrUITests

# Everything CI requires, in one go
xcodebuild test -project Trainr.xcodeproj -scheme Trainr \
  -destination "$DEST" -only-testing:TrainrTests && swiftlint lint --strict
```

A UI test failure keeps its screen recording. Read the result and export the
attachments:

```bash
xcrun xcresulttool get test-results tests --path <bundle>.xcresult
xcrun xcresulttool export attachments --path <bundle>.xcresult --output-path ./out
```

## Xcode and toolchain

Local Xcode is a 27 beta; CI runs `macos-26`, which ships Xcode 26 only. **Never
use an API that exists solely in the 27 SDK** — it compiles here and fails there.

Xcode 27 has no Simulator.app: the device window lives in DeviceHub, inside the
Xcode bundle. `xcrun simctl boot` alone runs the device headless.

Xcode rewrites `project.pbxproj` when it is open across a branch switch, usually
only reordering the same content. Check before you stage it:

```bash
git show HEAD:Trainr.xcodeproj/project.pbxproj | sort > /tmp/a
sort Trainr.xcodeproj/project.pbxproj > /tmp/b
diff -q /tmp/a /tmp/b && git checkout -- Trainr.xcodeproj/project.pbxproj
```

New source files never need a project edit: the targets use synchronized
folders, so a file in the folder is a file in the target.

## Strings

Never type a user-facing string into a view. They are generated from the Android
app's `strings.xml`, so both apps say exactly the same things:

```bash
./scripts/generate-strings.sh
```

That writes `Localizable.xcstrings` and the `L10n` accessors. Edit the Android
strings and regenerate; never edit either output by hand.

## Dependencies

Third-party packages are declared in `Packages/TrainrDependencies/Package.swift`
with exact versions, not in the Xcode project — Dependabot can read a manifest
and cannot read a `pbxproj`. Updates arrive as PRs every Monday and go through
the same CI as anything else.

## Firebase

The app builds and runs without `GoogleService-Info.plist`; generation falls
back to the canned coach. Live generation needs the plist in
`Trainr/Resources/`, and it is git-ignored — it must never be committed.

## Breaking glass

Branch protection allows an admin bypass, for the case where CI itself is broken
and you need to fix it. Using it should feel like a small failure, and the next
PR should explain why it was necessary.
