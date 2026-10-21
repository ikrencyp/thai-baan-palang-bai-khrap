import Foundation

enum DisplayPolicy {
    static func holdsDisplay(awake: Bool, keepScreenOn: Bool = true, darkenWhenClosed: Bool, locked: Bool, lidClosed: Bool) -> Bool {
        awake && keepScreenOn && !(darkenWhenClosed && (locked || lidClosed))
    }
}
