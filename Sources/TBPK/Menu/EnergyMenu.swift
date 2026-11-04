import AppKit

// Energy use lives in Power rules. Its rows leave the menu open and redraw from the stored values, so a choice shows
// its effect (the tick, the "Right now" line, the two sources) on the spot instead of closing the menu.
@MainActor
enum EnergyMenu {
    @MainActor
    struct Snapshot {
        let charger: EnergyProfile
        let battery: EnergyProfile
        let separate: Bool
        let plan: EnergyPlan
        let conditions: EnergyPlan.Conditions

        static func live() -> Snapshot {
            Snapshot(charger: .stored(.charger), battery: .stored(.battery), separate: EnergyProfile.isSeparate(),
                     plan: EnergyMonitor.shared.plan, conditions: EnergyMonitor.conditions())
        }

        var active: EnergyProfile { separate && conditions.onBattery ? battery : charger }
        var statusLine: String { EnergyMenu.status(active, plan, conditions) }

        var subtitle: String {
            separate ? "Charger \(charger.title), battery \(battery.title)" : "\(charger.title), \(plan.summary.lowercased())"
        }

        func slotSubtitle(_ slot: EnergyProfile.Slot) -> String {
            let stored = slot == .battery ? battery : charger
            return (slot == .battery) == conditions.onBattery ? "\(stored.title), in use now" : stored.title
        }
    }

    static func item(target: StatusMenuTarget) -> NSMenuItem {
        let parent = MenuParts.parent("Energy use", symbol: "bolt", subtitle: nil, submenu: NSMenu())
        Live(parent: parent, target: target).build()
        return parent
    }

    // A fixed picture of the menu (no live rows): what the unit tests and any static use read.
    static func item(target: StatusMenuTarget, charger: EnergyProfile, battery: EnergyProfile, separate: Bool,
                     plan: EnergyPlan, conditions: EnergyPlan.Conditions) -> NSMenuItem {
        let snapshot = Snapshot(charger: charger, battery: battery, separate: separate, plan: plan, conditions: conditions)
        let submenu = NSMenu()
        populate(submenu, snapshot, target: target, live: nil)
        return MenuParts.parent("Energy use", symbol: "bolt", subtitle: snapshot.subtitle, submenu: submenu)
    }

    // Owns the open menu's redraw. Rows hold it; it holds only weak views, so nothing leaks once the menu is gone.
    @MainActor
    private final class Live {
        let group = MenuRefresher()
        let target: StatusMenuTarget
        weak var parent: NSMenuItem?
        private var shownSeparate = false

        init(parent: NSMenuItem, target: StatusMenuTarget) {
            self.parent = parent
            self.target = target
        }

        func build() {
            guard let parent, let submenu = parent.submenu else { return }
            let snapshot = Snapshot.live()
            shownSeparate = snapshot.separate
            group.reset()
            submenu.removeAllItems()
            populate(submenu, snapshot, target: target, live: self)
            group.add { [weak self] in self?.sync() }
            group.add { [weak parent] in parent.map { MenuParts.setSubtitle(Snapshot.live().subtitle, on: $0) } }
            MenuParts.setSubtitle(snapshot.subtitle, on: parent)
        }

        // The switch row holds this object, so it lives as long as the open menu does.
        func pressSeparate(_ item: NSMenuItem) { target.energySeparateClicked(item) }

        // The list changes shape when "separate" flips (one list becomes two). That is done after the click has
        // finished, so the row that was pressed is not taken out of the menu while it is still handling the press.
        private func sync() {
            guard Snapshot.live().separate != shownSeparate else { return }
            DispatchQueue.main.async { [weak self] in self?.build() }
        }
    }

    private static func populate(_ menu: NSMenu, _ snapshot: Snapshot, target: StatusMenuTarget, live: Live?) {
        if snapshot.separate {
            menu.addItem(slotMenu("On the charger", symbol: "bolt.fill", slot: .charger, snapshot: snapshot, target: target, live: live))
            menu.addItem(slotMenu("On battery", symbol: "battery.75", slot: .battery, snapshot: snapshot, target: target, live: live))
        } else {
            choices(.charger, snapshot: snapshot, in: menu, target: target, live: live)
        }
        menu.addItem(.separator())
        menu.addItem(separateToggle(snapshot, target: target, live: live))
        let line = MenuParts.info(snapshot.statusLine)
        menu.addItem(line)
        live?.group.add { [weak line] in line?.title = Snapshot.live().statusLine }
    }

    private static func separateToggle(_ snapshot: Snapshot, target: StatusMenuTarget, live: Live?) -> NSMenuItem {
        let title = "Set charger and battery separately"
        let item = MenuParts.action(title, symbol: nil, #selector(StatusMenuTarget.energySeparateClicked(_:)), target)
        item.state = snapshot.separate ? .on : .off
        guard let live else { return item }
        return MenuParts.stayOpen(item, group: live.group, title: { title }, isOn: { EnergyProfile.isSeparate() },
                                  pick: { [live, weak item] in item.map(live.pressSeparate) })
    }

    private static func slotMenu(_ title: String, symbol: String, slot: EnergyProfile.Slot, snapshot: Snapshot,
                                 target: StatusMenuTarget, live: Live?) -> NSMenuItem {
        let submenu = NSMenu()
        choices(slot, snapshot: snapshot, in: submenu, target: target, live: live)
        let parent = MenuParts.parent(title, symbol: symbol, subtitle: snapshot.slotSubtitle(slot), submenu: submenu)
        live?.group.add { [weak parent] in parent.map { MenuParts.setSubtitle(Snapshot.live().slotSubtitle(slot), on: $0) } }
        return parent
    }

    private static func choices(_ slot: EnergyProfile.Slot, snapshot: Snapshot, in menu: NSMenu, target: StatusMenuTarget,
                                live: Live?) {
        let stored = slot == .battery ? snapshot.battery : snapshot.charger
        for profile in EnergyProfile.allCases {
            let item = MenuParts.radio(profile.title, EnergyProfile.Pick(slot: slot, profile: profile), profile == stored,
                                       #selector(StatusMenuTarget.energyProfileClicked(_:)), target)
            if let live {
                menu.addItem(MenuParts.stayOpen(item, group: live.group, title: { profile.title },
                                                isOn: { EnergyProfile.stored(slot) == profile },
                                                pick: { [weak item] in item.map(target.energyProfileClicked) }))
            } else {
                MenuParts.setSubtitle(profile.detail, on: item)
                menu.addItem(item)
            }
        }
        guard let live else {
            if #unavailable(macOS 14.4), !snapshot.separate { menu.addItem(MenuParts.info(stored.detail)) }
            return
        }
        let detail = MenuParts.info(stored.detail)
        menu.addItem(.separator())
        menu.addItem(detail)
        live.group.add { [weak detail] in detail?.title = EnergyProfile.stored(slot).detail }
    }

    // What is happening now and, for Automatic, why: the person can see the setting do its job.
    static func status(_ profile: EnergyProfile, _ plan: EnergyPlan, _ conditions: EnergyPlan.Conditions) -> String {
        let now = "Right now: \(plan.summary.lowercased())"
        guard profile == .automatic, plan.isVisible else { return now }
        return "\(now) (\(conditions.reason))"
    }
}

extension EnergyPlan.Conditions {
    var reason: String {
        if reduceMotion { return "Reduce Motion is on" }
        if lowPowerMode { return "Low Power Mode is on" }
        return onBattery ? "on battery" : "on the charger"
    }
}
