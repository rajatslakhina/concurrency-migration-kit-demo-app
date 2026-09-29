# ConcurrencyMigrationKit — Demo App

**Open it and the first thing you see is a number: how much of this app's module graph is actually in Swift 6 language mode. One tab across is a suppression that has been lying to its team for weeks.**

A small SwiftUI app that drives [**ConcurrencyMigrationKit**](https://github.com/rajatslakhina/concurrency-migration-kit) against a realistic twelve-module commerce app part-way through the move to Swift 6.

The library is consumed here the way anyone else would consume it: as a **remote Swift package, pinned to a released version**. There is no local path reference and no `branch = main` anywhere in `project.pbxproj` — the project resolves `https://github.com/rajatslakhina/concurrency-migration-kit.git` at `upToNextMajorVersion` from `1.2.0`, exactly as a real consumer would.

## Why this matters

Moving a large app to Swift 6 has two hard parts, and writing `Sendable` conformances is neither of them.

The first is **sequencing**: a module can only migrate cleanly once everything it depends on has, so the dependency graph fixes the order. What it does not fix is how much you attempt at once — and that is the decision a lead owns. The **Migration plan** tab makes that split visible: the segmented control changes the per-wave effort budget, and the schedule re-plans live. The order never changes. The number of waves does.

The second is **the debt the first part creates**. Somebody always flips a module ahead of its dependencies, because a team is blocked and the quarter is ending, and a `@preconcurrency import` goes into a file. The **Suppression debt** tab audits those against the live graph. The app opens on the plan; one tap moves to the debt, where the fixture is built so that three different failure modes are visible at once:

- `Analytics → Logging` is marked **stale**. It was written when `Logging` was behind; `Logging` has since reached Swift 6 mode. It still compiles, nothing warns, and it is now discarding diagnostics about `Analytics`' own code.
- `Checkout → DesignSystem` is **overdue** — still load-bearing, but nobody has looked at it since the date they agreed to.
- `Search → Networking` is an **unrecorded inversion**. `Search` is in Swift 6 mode and `Networking` is not, so that suppression exists somewhere in the source with no owner, no reason and no review date. The audit finds it from the graph alone, which is the only way it can be found.

## Screenshots

**There are none, and none are implied.** No `Demo/Screenshots/` directory exists in this repository.

The pipeline that produced this repo requested control of the machine to open this project in Xcode and launch it on a Simulator. Access was granted — but Xcode already had an unrelated, real project open and actively debugging on a simulator, which is someone else's work in progress on the same machine. The run was abandoned without touching Xcode, per the pipeline's own safety rule.

## What has and has not been verified

These are two different statements and only one of them is true today:

- ✅ **This app compiles against the released package for an iOS Simulator destination.** The [CI job](https://github.com/rajatslakhina/concurrency-migration-kit-demo-app/actions) runs `xcodebuild -resolvePackageDependencies` — which proves the pinned remote package genuinely resolves from GitHub, rather than only that a URL was typed correctly — prints the resolved `Package.resolved`, and then runs `xcodebuild build -scheme Demo -destination 'generic/platform=iOS Simulator'`. The package reference is pinned at `upToNextMajorVersion` from `1.2.0`, so the job resolves the library release of the same name. The Actions tab above is the authority on any given commit, not this sentence.
- ❌ **This app has never been launched on a Simulator.** Not by CI, which compiles only, and not by a human, for the reason above. "It builds for a Simulator" is not "it ran on a Simulator," and this README will not pretend otherwise.

The library's own logic is separately covered by 67 XCTest cases that genuinely run, and its CI additionally compiles the SwiftUI target for iOS Simulator and macOS — see the [package repository](https://github.com/rajatslakhina/concurrency-migration-kit) and its [Actions tab](https://github.com/rajatslakhina/concurrency-migration-kit/actions).

The CI destination is `generic/platform=iOS Simulator` rather than a named device on purpose: pinning to `name=iPhone 16,OS=latest` ties the job to whichever simulator *runtimes* happen to be installed on that day's runner image, and they are not guaranteed. A compile-only check needs no device to exist.

## How to run it

```bash
git clone https://github.com/rajatslakhina/concurrency-migration-kit-demo-app.git
cd concurrency-migration-kit-demo-app
open Demo.xcodeproj
```

Then: let Xcode resolve the remote package (it fetches `concurrency-migration-kit` 1.2.0 or the latest 1.x above it, per the `upToNextMajorVersion` pin), select the shared **Demo** scheme, pick any iOS 17+ Simulator, and Build & Run. The scheme is committed under `Demo.xcodeproj/xcshareddata/xcschemes/`, so it is selectable on a fresh clone without configuration.

Nothing is code-signed (`CODE_SIGNING_ALLOWED = NO`), so a Simulator build needs no team or certificate.

## Where the data comes from

`Demo/DemoApp.swift` owns the entire fixture — the twelve-module graph and the four-entry suppression ledger — and passes them into the library's `MigrationDashboardView`. The library ships no fixture of its own and no global state; a host app would build the same inputs from its own package manifests and a checked-in ledger file.

The app imports **both** library products for real reasons: `ConcurrencyMigrationKit` for the `ModuleGraph`, `ModuleNode` and `ExemptionEntry` types the fixture is built from, and `ConcurrencyMigrationKitUI` for the screen that renders them. Building the graph can fail, and the library's typed `throws(GraphError)` says exactly how — so the app surfaces the failure in a `ContentUnavailableView` instead of force-trying and crashing on launch.

## Licence

MIT. See [LICENSE](LICENSE).
