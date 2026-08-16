// Unit tests for the pure Timeline/Gantt logic that ships in the app.
//
// TimelineModel.swift imports Foundation only, so it compiles and runs on Linux even though
// the rest of Arkboard needs AppKit. Run with ./scripts/gantt_check.sh.

import Foundation

var passed = 0
var failed = 0

func check(_ name: String, _ condition: Bool, _ detail: String = "") {
    if condition {
        print("PASS  \(name)")
        passed += 1
    } else {
        print("FAIL  \(name)" + (detail.isEmpty ? "" : " — \(detail)"))
        failed += 1
    }
}

func equal<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
    check(name, actual == expected, "got \(actual), want \(expected)")
}

func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    GanttMath.calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))!
}

func label(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = GanttMath.calendar
    formatter.locale = Locale(identifier: "en_GB")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}

// MARK: - Axis columns

equal("week column starts on Monday", label(GanttMath.columnStart(containing: day(2026, 8, 15), scale: .week)), "2026-08-10")
equal("week column start is idempotent", label(GanttMath.columnStart(containing: day(2026, 8, 10), scale: .week)), "2026-08-10")
equal("month column starts on the first", label(GanttMath.columnStart(containing: day(2026, 8, 15), scale: .month)), "2026-08-01")
equal("year column starts on 1 January", label(GanttMath.columnStart(containing: day(2026, 8, 15), scale: .year)), "2026-01-01")
equal("year column start is idempotent", label(GanttMath.columnStart(containing: day(2026, 1, 1), scale: .year)), "2026-01-01")
equal("year column starts on this year from December", label(GanttMath.columnStart(containing: day(2026, 12, 31), scale: .year)), "2026-01-01")

equal("advance one week", label(GanttMath.advance(day(2026, 8, 10), scale: .week, by: 1)), "2026-08-17")
equal("advance back one month", label(GanttMath.advance(day(2026, 8, 1), scale: .month, by: -1)), "2026-07-01")
equal("advance one year", label(GanttMath.advance(day(2026, 1, 1), scale: .year, by: 1)), "2027-01-01")
equal("advance back one year", label(GanttMath.advance(day(2026, 1, 1), scale: .year, by: -1)), "2025-01-01")

equal("week column label", GanttMath.columnLabel(day(2026, 8, 10), scale: .week), "10 Aug")
equal("month column label", GanttMath.columnLabel(day(2026, 8, 1), scale: .month), "Aug 2026")
equal("year column label", GanttMath.columnLabel(day(2026, 1, 1), scale: .year), "2026")
equal("year column label from mid-year start", GanttMath.columnLabel(GanttMath.columnStart(containing: day(2027, 8, 15), scale: .year), scale: .year), "2027")

// MARK: - Window

let monthWindow = GanttMath.window(covering: [day(2026, 8, 20)], scale: .month, now: day(2026, 8, 15))
equal("month window pads one column before", label(monthWindow.start), "2026-07-01")
equal("month window reaches the minimum column count", label(monthWindow.end), "2026-11-01")
equal(
    "month window columns",
    GanttMath.columns(in: monthWindow, scale: .month).map(label),
    ["2026-07-01", "2026-08-01", "2026-09-01", "2026-10-01"]
)

let pastWindow = GanttMath.window(covering: [day(2026, 1, 10), day(2026, 2, 10)], scale: .month, now: day(2026, 8, 15))
check("window always contains today", pastWindow.start <= day(2026, 8, 15) && day(2026, 8, 15) <= pastWindow.end)
check(
    "window covers every milestone",
    pastWindow.start <= day(2026, 1, 10) && day(2026, 2, 10) <= pastWindow.end
)

let weekWindow = GanttMath.window(covering: [day(2026, 8, 18)], scale: .week, now: day(2026, 8, 17))
equal("week window starts a Monday", label(weekWindow.start), "2026-08-10")
equal("week window holds the minimum columns", GanttMath.columns(in: weekWindow, scale: .week).count, 6)

let emptyWindow = GanttMath.window(covering: [], scale: .month, now: day(2026, 8, 15))
equal("empty window still has an axis", GanttMath.columns(in: emptyWindow, scale: .month).count, 4)

// MARK: - Positions

let year = GanttWindow(start: day(2026, 1, 1), end: day(2027, 1, 1))
equal("start sits at zero", GanttMath.fraction(of: day(2026, 1, 1), in: year), 0)
equal("end sits at one", GanttMath.fraction(of: day(2027, 1, 1), in: year), 1)
equal("before the window clamps to zero", GanttMath.fraction(of: day(2025, 6, 1), in: year), 0)
equal("after the window clamps to one", GanttMath.fraction(of: day(2028, 6, 1), in: year), 1)
check(
    "1 July 2026 sits at 181/365",
    abs(GanttMath.fraction(of: day(2026, 7, 1), in: year) - 181.0 / 365.0) < 1e-9,
    String(GanttMath.fraction(of: day(2026, 7, 1), in: year))
)
check(
    "positions increase with time",
    GanttMath.fraction(of: day(2026, 3, 1), in: year) < GanttMath.fraction(of: day(2026, 9, 1), in: year)
)

// MARK: - Plan

let arkboard = GanttProjectInput(id: "p-ark", key: "ARK", name: "Arkboard", color: "#5A62D6")
let lumen = GanttProjectInput(id: "p-lum", key: "LUM", name: "Lumen", color: "#1F8F63")

let design = GanttMilestoneInput(
    id: "m-design", projectId: "p-ark", title: "Design pack locked",
    targetDate: day(2026, 8, 20), status: .done
)
let build = GanttMilestoneInput(
    id: "m-build", projectId: "p-ark", title: "Gantt ships",
    targetDate: day(2026, 9, 18), status: .inProgress, dependsOn: ["m-design"]
)
let ship = GanttMilestoneInput(
    id: "m-ship", projectId: "p-ark", title: "Studio board v3",
    targetDate: day(2026, 10, 30), status: .planned, dependsOn: ["m-build", "m-design"]
)
let lumenKickoff = GanttMilestoneInput(
    id: "m-lum", projectId: "p-lum", title: "Lumen kickoff",
    targetDate: day(2026, 9, 4), status: .planned
)
let studioReview = GanttMilestoneInput(
    id: "m-studio", projectId: nil, title: "Studio review",
    targetDate: day(2026, 9, 25), status: .planned
)
let shipped = GanttEventInput(
    id: "i-1", projectId: "p-ark", identifier: "ARK-14", title: "Overlay Contents",
    date: day(2026, 8, 12)
)

let plan = GanttPlanner.plan(
    projects: [arkboard, lumen],
    milestones: [design, build, ship, lumenKickoff, studioReview],
    events: [shipped],
    scope: nil,
    scale: .month,
    now: day(2026, 8, 15)
)

equal(
    "rows are projects with milestones underneath",
    plan.rows.map { "\($0.kind.rawValue):\($0.id)" },
    [
        "project:p-ark", "milestone:m-design", "milestone:m-build", "milestone:m-ship",
        "project:p-lum", "milestone:m-lum",
        "project:studio", "milestone:m-studio",
    ]
)
equal("project rows count their milestones", plan.rows.first { $0.id == "p-ark" }?.milestoneCount, 3)
equal(
    "a project bar spans its whole plan",
    [
        label(plan.rows.first { $0.id == "p-ark" }!.start),
        label(plan.rows.first { $0.id == "p-ark" }!.end),
    ],
    ["2026-08-12", "2026-10-30"]
)
equal(
    "shipped work is a mark on the project row, not a row",
    plan.rows.first { $0.id == "p-ark" }?.marks.map(\.id),
    ["i-1"]
)
equal("no row is created for a completed issue", plan.rows.contains { $0.id == "i-1" }, false)

equal(
    "a milestone with no predecessor starts at its project start",
    label(plan.rows.first { $0.id == "m-design" }!.start),
    "2026-08-12"
)
equal(
    "a milestone starts when its predecessor lands",
    label(plan.rows.first { $0.id == "m-build" }!.start),
    "2026-08-20"
)
equal(
    "a milestone waits for its latest predecessor",
    label(plan.rows.first { $0.id == "m-ship" }!.start),
    "2026-09-18"
)
equal(
    "every milestone row carries a diamond at its target",
    plan.rows.filter { $0.kind == .milestone }.allSatisfy { $0.marker == $0.end },
    true
)
equal(
    "links run predecessor to successor",
    plan.links.map(\.id).sorted(),
    ["m-build->m-ship", "m-design->m-build", "m-design->m-ship"]
)
equal("studio milestones get their own row", plan.rows.first { $0.id == "studio" }?.title, "Studio")
equal("the studio row is not a project", plan.rows.first { $0.id == "studio" }?.projectId, nil)

let scoped = GanttPlanner.plan(
    projects: [arkboard, lumen],
    milestones: [design, build, ship, lumenKickoff, studioReview],
    events: [shipped],
    scope: "p-ark",
    scale: .month,
    now: day(2026, 8, 15)
)
equal(
    "a scoped plan is the same chart, filtered",
    scoped.rows.map(\.id),
    ["p-ark", "m-design", "m-build", "m-ship"]
)
equal("a scoped plan keeps its links", scoped.links.count, 3)
equal("a scoped plan drops other projects", scoped.rows.contains { $0.id == "p-lum" }, false)
equal("a scoped plan drops studio milestones", scoped.rows.contains { $0.id == "studio" }, false)

let dangling = GanttPlanner.plan(
    projects: [arkboard],
    milestones: [
        GanttMilestoneInput(
            id: "m-only", projectId: "p-ark", title: "Alone",
            targetDate: day(2026, 9, 1), status: .planned, dependsOn: ["m-missing"]
        )
    ],
    events: [],
    scope: nil,
    scale: .month,
    now: day(2026, 8, 15)
)
equal("a predecessor outside the chart draws no link", dangling.links.isEmpty, true)
equal("a predecessor outside the chart is not listed", dangling.rows.last?.dependsOn, [])

let backwards = GanttPlanner.plan(
    projects: [arkboard],
    milestones: [
        GanttMilestoneInput(id: "m-late", projectId: "p-ark", title: "Late", targetDate: day(2026, 11, 1), status: .planned),
        GanttMilestoneInput(
            id: "m-early", projectId: "p-ark", title: "Early",
            targetDate: day(2026, 9, 1), status: .planned, dependsOn: ["m-late"]
        ),
    ],
    events: [],
    scope: nil,
    scale: .month,
    now: day(2026, 8, 15)
)
equal(
    "a predecessor dated after its successor does not invert the bar",
    label(backwards.rows.first { $0.id == "m-early" }!.start),
    "2026-09-01"
)

equal("an empty plan has no rows", GanttPlanner.plan(projects: [arkboard], milestones: [], events: []).isEmpty, true)

// MARK: - Dependencies

equal(
    "dependency ids are trimmed and deduplicated",
    GanttDependencies.normalise([" a ", "a", "", "   ", "b"]),
    ["a", "b"]
)
equal(
    "depending on a milestone that depends on you is a cycle",
    GanttDependencies.createsCycle(milestoneId: "a", candidates: ["b"], edges: ["b": ["a"]]),
    true
)
equal(
    "a longer loop is still a cycle",
    GanttDependencies.createsCycle(milestoneId: "a", candidates: ["c"], edges: ["c": ["b"], "b": ["a"]]),
    true
)
equal(
    "a chain is not a cycle",
    GanttDependencies.createsCycle(milestoneId: "c", candidates: ["b"], edges: ["b": ["a"]]),
    false
)
equal(
    "depending on yourself is a cycle",
    GanttDependencies.createsCycle(milestoneId: "a", candidates: ["a"], edges: [:]),
    true
)
equal(
    "a diamond graph is not a cycle",
    GanttDependencies.createsCycle(milestoneId: "d", candidates: ["b", "c"], edges: ["b": ["a"], "c": ["a"]]),
    false
)

// MARK: - Scale

equal("scales are week, month, year", TimelineScale.allCases.map(\.rawValue), ["week", "month", "year"])
equal("scale labels", TimelineScale.allCases.map(\.label), ["Week", "Month", "Year"])

print("")
if failed > 0 {
    print("\(failed) failed, \(passed) passed.")
    exit(1)
}
print("All \(passed) checks passed.")
