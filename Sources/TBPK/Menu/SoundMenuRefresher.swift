import AppKit

// A choice made in the sound menu changes more than its own row (the ticks, the counts, the lines under the
// headings). Because the menu stays open, every one of those is redrawn from the stored values right away.
@MainActor
final class SoundMenuRefresher {
    private var refreshers: [() -> Void] = []

    func add(_ refresh: @escaping () -> Void) { refreshers.append(refresh) }

    func run() { refreshers.forEach { $0() } }
}
