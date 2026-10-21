### PL0.4 · Reproducible packages                                         size: S
Place in the tree: product › platform foundations › build reproducibility › pinned package graph
Repo · branch: NPRdoinglaundry · pl/PL0.4-pinned-packages
Needs: none (first byte; land before anything adds a package)      Unblocks: PL2.0 (GRDB), PL6.1 (RevenueCat), every later byte's CI stability

Why: today a build on Monday and a build on Friday can compile different Google code, because one package floats on `main` and no lockfile is committed. After this, the same commit always builds the same app.

Inputs (read these, nothing else is needed):
- Reference: app-reference.md §13 (package refs, both .gitignore files)
- Code anchors:
  - `Retrospect/Retrospect.xcodeproj/project.pbxproj:983-1000`: `XCRemoteSwiftPackageReference` for `GoogleSignIn-iOS` (`upToNextMajorVersion`, minimum 8.0.0) and `google-api-objectivec-client-for-rest` (`kind = branch; branch = main;`).
  - `Retrospect/.gitignore:29` `Package.resolved` and `:30` `*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
  - root `.gitignore:31-32`: the same two patterns.

Spec:
- `google-api-objectivec-client-for-rest`: change the requirement from `branch = main` to `kind = exactVersion` at the newest tagged release that builds and passes today's app (record the version in the PR). Use Xcode's package editor (File › Packages) so the pbxproj is written by Xcode, not by hand.
- `GoogleSignIn-iOS`: change `upToNextMajorVersion 8.0.0` to `exactVersion` at the version currently resolved (record it). It must be ≥ 7.1 for the nonce-taking sign-in used in PL1.4; 8.x satisfies that.
- Commit `Retrospect/Retrospect.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- `.gitignore` exceptions: in both files, keep ignoring stray `Package.resolved` files elsewhere, but add `!Retrospect/Retrospect.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (root) and `!Retrospect.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (Retrospect/.gitignore) **after** the ignore lines (gitignore order matters). The `.gitignore` edits are the integrator's to approve: list them first in the PR body.
- Rule written into the PR body for every later package: exact versions only, `Package.resolved` changes reviewed like code.

Steps: resolve packages in Xcode → note resolved versions → switch both to exact → commit pbxproj + Package.resolved → gitignore exceptions → clean build twice from a fresh clone.

Acceptance:
- `git ls-files | grep Package.resolved` shows exactly the one file.
- Both package references in the pbxproj are `exactVersion`.
- A fresh clone (`git clone` into a temp folder, `xcodebuild -resolvePackageDependencies`, then build) resolves the same versions as the committed file, twice.
- The app builds and launches exactly as before (no code changes).

Tests: none new (no code). Proof is the reproducible build.

Proof in the PR: the two resolved versions; the output of `xcodebuild -resolvePackageDependencies` from the fresh clone; `git diff --stat` showing only pbxproj, Package.resolved and the two .gitignore files.

Watch out:
- Don't hand-edit `project.pbxproj` text; let Xcode write it, then read the diff.
- The `.gitignore` negation must come after the ignore lines in the same file, or it's ignored.
- CI's `ios` job uses `-derivedDataPath "$RUNNER_TEMP/dd"` and resolves packages fresh: watch the first CI run on this PR for a resolution error before calling it done.
