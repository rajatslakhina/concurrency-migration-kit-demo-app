import Foundation
import SwiftUI
import ConcurrencyMigrationKit
import ConcurrencyMigrationKitUI

/// The app owns the data; the library owns the reasoning about it.
///
/// `ConcurrencyMigrationKit` is imported for the graph and ledger types this fixture is
/// built out of, and `ConcurrencyMigrationKitUI` for the screen that renders them. The
/// library ships no fixture of its own — a host app would build this from its own package
/// manifests and a checked-in ledger file instead.
enum DemoFleet {

    /// The date the audit is run against. Fixed rather than `.now` so what CI builds and
    /// what you see on launch are the same thing, forever — an audit keyed on the wall
    /// clock would quietly change its own findings as review dates passed.
    static let referenceDate = day(2026, 9, 29)

    /// A mid-sized commerce app, part-way through the move to Swift 6.
    ///
    /// Note `Search` and `Telemetry`: both are already in Swift 6 language mode while
    /// `Networking` underneath them is not. That is not a mistake in the fixture — it is
    /// the situation the package exists for, and only one of the two wrote it down.
    static let modules: [ModuleNode] = [
        ModuleNode(id: "CoreTypes", posture: .swift6, owningTeam: "Platform"),
        ModuleNode(id: "Logging", posture: .swift6, owningTeam: "Platform"),
        ModuleNode(id: "DesignSystem", posture: .swift5Complete, openDiagnostics: 9, owningTeam: "Design"),
        ModuleNode(
            id: "Networking", posture: .swift5Targeted,
            dependencies: ["CoreTypes", "Logging"], openDiagnostics: 24, owningTeam: "Platform"
        ),
        ModuleNode(
            id: "Persistence", posture: .swift5Targeted,
            dependencies: ["CoreTypes"], openDiagnostics: 16, owningTeam: "Data"
        ),
        ModuleNode(id: "Analytics", posture: .swift6, dependencies: ["Logging"], owningTeam: "Growth"),
        ModuleNode(id: "Telemetry", posture: .swift6, dependencies: ["Networking"], owningTeam: "Growth"),
        ModuleNode(
            id: "Search", posture: .swift6,
            dependencies: ["Networking", "Persistence"], owningTeam: "Discovery"
        ),
        ModuleNode(
            id: "SyncEngine", posture: .swift5Unchecked,
            dependencies: ["Networking", "Persistence"], openDiagnostics: 33, owningTeam: "Data"
        ),
        ModuleNode(
            id: "Checkout", posture: .swift5Unchecked,
            dependencies: ["Networking", "DesignSystem"], openDiagnostics: 21, owningTeam: "Payments"
        ),
        ModuleNode(
            id: "Profile", posture: .swift5Unchecked,
            dependencies: ["Persistence", "DesignSystem", "Analytics"],
            openDiagnostics: 12, owningTeam: "Growth"
        ),
        ModuleNode(
            id: "AppShell", posture: .swift5Unchecked,
            dependencies: ["SyncEngine", "Checkout", "Profile", "Search", "Telemetry"],
            openDiagnostics: 8, owningTeam: "Platform"
        ),
    ]

    /// The `@preconcurrency import`s somebody remembered to record.
    ///
    /// One of them is the interesting one. `Analytics -> Logging` was written when
    /// `Logging` was behind; `Logging` has since reached Swift 6 mode, and nothing in the
    /// toolchain noticed. It still compiles. It is now suppressing diagnostics about
    /// `Analytics`' own code, and the Suppression debt tab is the only thing that says so.
    static let ledger: [ExemptionEntry] = [
        ExemptionEntry(
            module: "Analytics", importedModule: "Logging",
            owner: "growth-platform",
            reason: "Logging's handler types were not Sendable when Analytics migrated.",
            reviewBy: day(2026, 12, 15)
        ),
        ExemptionEntry(
            module: "Telemetry", importedModule: "Networking",
            owner: "growth-platform",
            reason: "Telemetry shipped ahead of Networking to unblock the 27.2 release.",
            reviewBy: day(2026, 11, 30)
        ),
        ExemptionEntry(
            module: "Search", importedModule: "Persistence",
            owner: "discovery",
            reason: "Query cache types cross the actor boundary; blocked on Persistence.",
            reviewBy: day(2026, 11, 15)
        ),
        ExemptionEntry(
            module: "Checkout", importedModule: "DesignSystem",
            owner: "payments",
            reason: "Theme objects are main-actor-bound but not annotated upstream.",
            reviewBy: day(2026, 8, 1)
        ),
        // Deliberately absent: `Search -> Networking`. Search is in Swift 6 mode and
        // Networking is not, so that suppression exists in the source somewhere — with no
        // owner, no reason and no review date. The audit finds it from the graph alone.
    ]

    /// Building the graph can fail, and the typed `throws(GraphError)` says exactly how —
    /// so the app surfaces the failure instead of force-trying and crashing on launch.
    static func load() -> Result<ModuleGraph, GraphError> {
        do {
            return .success(try ModuleGraph(modules))
        } catch {
            return .failure(error)
        }
    }

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        // A fixed, well-formed date from this file. If it ever stops resolving, fall back
        // to a value that makes every comparison obviously wrong rather than plausibly right.
        return calendar.date(from: components) ?? .distantPast
    }
}

struct DemoRootView: View {
    var body: some View {
        switch DemoFleet.load() {
        case .success(let graph):
            MigrationDashboardView(
                graph: graph,
                exemptions: DemoFleet.ledger,
                referenceDate: DemoFleet.referenceDate
            )
        case .failure(let error):
            ContentUnavailableView(
                "The demo fixture is not a valid graph",
                systemImage: "exclamationmark.triangle",
                description: Text(error.description)
            )
        }
    }
}

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoRootView()
        }
    }
}
