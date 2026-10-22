import Foundation

// Reads the Mac's power draw on a slow timer, only while the leaf is beating, and tells the icon when the level moves
// by a tenth. Nothing runs when there is no heartbeat to shape.
@MainActor
final class PowerDrawMeter {
    private(set) var level = PowerIntensity.unknown
    var onChange: (() -> Void)?
    private var timer: Timer?
    private var interval: TimeInterval?
    private var smoothed: Double?
    private let read: () -> Double?

    init(read: @escaping () -> Double? = SystemPower.watts) {
        self.read = read
    }

    func run(every wanted: TimeInterval?) {
        guard wanted != interval else { return }
        interval = wanted
        timer?.invalidate()
        timer = nil
        guard let wanted else { return }
        sampleNow()
        let next = Timer(timeInterval: wanted, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleNow() }
        }
        next.tolerance = wanted * 0.25
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    func sampleNow() {
        guard let watts = read() else { return }
        let reading = PowerIntensity.level(watts: watts)
        let next = smoothed.map { PowerIntensity.smoothed(previous: $0, next: reading) } ?? reading
        smoothed = next
        let shown = PowerIntensity.quantised(next)
        guard shown != level else { return }
        level = shown
        onChange?()
    }
}
