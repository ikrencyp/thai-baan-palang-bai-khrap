import AppKit

// A choice made in a menu that stays open changes more than its own row (the ticks, the counts, the lines under the
// headings). Every one of those is redrawn from the stored values right away.
@MainActor
final class MenuRefresher {
    private var refreshers: [() -> Void] = []

    func add(_ refresh: @escaping () -> Void) { refreshers.append(refresh) }

    func reset() { refreshers.removeAll() }

    func run() { refreshers.forEach { $0() } }
}
