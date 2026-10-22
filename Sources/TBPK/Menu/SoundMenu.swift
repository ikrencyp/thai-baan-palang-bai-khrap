import AppKit

@MainActor
enum SoundMenu {
    static let percentTag = 4201

    static func item(target: StatusMenuTarget) -> NSMenuItem {
        let group = SoundMenuRefresher()
        let submenu = NSMenu()
        addChoices(to: submenu, target: target, group: group)
        submenu.addItem(.separator())
        submenu.addItem(beepCount(target: target, group: group))
        submenu.addItem(volume(target: target))
        let parent = MenuParts.parent("Alert sound", symbol: "speaker.wave.2", subtitle: AlertSound.stored.displayName,
                                      submenu: submenu)
        group.add { MenuParts.setSubtitle(AlertSound.stored.displayName, on: parent) }
        return parent
    }

    // The sound rows when they sit inside another menu (Alerts): the choices fold into one "Sound" row, so the count and
    // the volume stay one click away. `group` is shared with the host menu so its own lines refresh with every pick.
    static func rows(target: StatusMenuTarget, group: SoundMenuRefresher) -> [NSMenuItem] {
        let choices = NSMenu()
        addChoices(to: choices, target: target, group: group)
        let sound = MenuParts.parent("Sound", symbol: "music.note", subtitle: AlertSound.stored.displayName, submenu: choices)
        group.add { MenuParts.setSubtitle(AlertSound.stored.displayName, on: sound) }
        return [sound, beepCount(target: target, group: group), volume(target: target)]
    }

    static func percentText(_ level: Float32) -> String {
        "\(Int((level * 100).rounded()))%"
    }

    // Two groups, so it is clear where a sound comes from: added by the person, owned by macOS.
    private static func addChoices(to menu: NSMenu, target: StatusMenuTarget, group: SoundMenuRefresher) {
        menu.addItem(MenuParts.info("Pick a sound, then press play below"))
        menu.addItem(.separator())
        menu.addItem(MenuParts.sectionHeader("My sounds"))
        let mine = CustomSoundLibrary.sounds
        mine.forEach { menu.addItem(choice($0, target: target, group: group)) }
        menu.addItem(MenuParts.action("Add sound files…", symbol: "plus.circle",
                                      #selector(StatusMenuTarget.chooseSoundClicked), target))
        if !mine.isEmpty { menu.addItem(removeChoices(mine, target: target)) }
        menu.addItem(.separator())
        menu.addItem(macSounds(target: target, group: group))
    }

    // A row that picks the sound and leaves the menu open. The item keeps its action, so the keyboard still works.
    private static func choice(_ sound: AlertSound, target: StatusMenuTarget, group: SoundMenuRefresher) -> NSMenuItem {
        let item = MenuParts.radio(sound.displayName, sound.name, sound == AlertSound.stored,
                                   #selector(StatusMenuTarget.alertSoundClicked(_:)), target)
        return stayOpen(item, group: group, title: { sound.displayName }, detail: { AlertBeepCount.stored(for: sound).label },
                        isOn: { AlertSound.stored == sound }, pick: { [weak item] in item.map(target.alertSoundClicked) })
    }

    private static func stayOpen(_ item: NSMenuItem, group: SoundMenuRefresher, title: @escaping () -> String,
                                 detail: @escaping () -> String? = { nil }, isOn: @escaping () -> Bool,
                                 pick: @escaping () -> Void) -> NSMenuItem {
        let row = StayOpenRow(title: title, detail: detail, isOn: isOn, pick: { pick(); group.run() })
        item.view = row
        group.add { [weak row, weak item] in
            item?.state = isOn() ? .on : .off
            row?.needsDisplay = true
        }
        return item
    }

    private static func macSounds(target: StatusMenuTarget, group: SoundMenuRefresher) -> NSMenuItem {
        let submenu = NSMenu()
        let sounds = AlertSound.available.filter { !$0.isCustom }
        sounds.forEach { submenu.addItem(choice($0, target: target, group: group)) }
        let subtitle = { sounds.contains(AlertSound.stored) ? AlertSound.stored.displayName : nil }
        let parent = MenuParts.parent("Mac sounds", symbol: "desktopcomputer", subtitle: subtitle(), submenu: submenu)
        group.add { subtitle().map { MenuParts.setSubtitle($0, on: parent) } }
        return parent
    }

    private static func removeChoices(_ sounds: [AlertSound], target: StatusMenuTarget) -> NSMenuItem {
        let submenu = NSMenu()
        for sound in sounds {
            let item = MenuParts.action(sound.displayName, symbol: nil,
                                        #selector(StatusMenuTarget.removeCustomSoundClicked(_:)), target)
            item.representedObject = sound.name
            submenu.addItem(item)
        }
        return MenuParts.parent("Remove one of my sounds", symbol: "trash", subtitle: nil, submenu: submenu)
    }

    private static func beepCount(target: StatusMenuTarget, group: SoundMenuRefresher) -> NSMenuItem {
        let submenu = NSMenu()
        let heading = MenuParts.info(countHeading())
        submenu.addItem(heading)
        submenu.addItem(.separator())
        for count in AlertBeepCount.allCases {
            let item = MenuParts.radio(count.label, count.rawValue, count == AlertBeepCount.stored(for: AlertSound.stored),
                                       #selector(StatusMenuTarget.beepCountClicked(_:)), target)
            submenu.addItem(stayOpen(item, group: group, title: { count.label },
                                     isOn: { count == AlertBeepCount.stored(for: AlertSound.stored) },
                                     pick: { [weak item] in item.map(target.beepCountClicked) }))
        }
        submenu.addItem(.separator())
        let all = MenuParts.action("Use the same for every sound", symbol: nil,
                                   #selector(StatusMenuTarget.sharedBeepCountClicked), target)
        all.state = AlertBeepCount.isShared() ? .on : .off
        submenu.addItem(stayOpen(all, group: group, title: { "Use the same for every sound" }, isOn: { AlertBeepCount.isShared() },
                                 pick: { target.sharedBeepCountClicked() }))
        let parent = MenuParts.parent("Play how many times", symbol: "repeat", subtitle: AlertBeepCount.stored(for: AlertSound.stored).label,
                                      submenu: submenu)
        group.add {
            heading.title = countHeading()
            MenuParts.setSubtitle(AlertBeepCount.stored(for: AlertSound.stored).label, on: parent)
        }
        return parent
    }

    private static func countHeading() -> String {
        AlertBeepCount.isShared() ? "Same for every sound" : "For \(AlertSound.stored.displayName)"
    }

    private static func volume(target: StatusMenuTarget) -> NSMenuItem {
        let level = AlertVolumeLift.storedLevel
        let item = NSMenuItem(title: "Alert volume", action: nil, keyEquivalent: "")
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 292, height: 26))
        let title = MenuParts.label("Alert volume", frame: NSRect(x: 28, y: 3, width: 92, height: 17))
        let slider = NSSlider(value: Double(level), minValue: 0, maxValue: 1, target: target,
                              action: #selector(StatusMenuTarget.alertVolumeChanged(_:)))
        slider.frame = NSRect(x: 124, y: 1, width: 84, height: 22)
        slider.isContinuous = true
        let percent = MenuParts.label(percentText(level), frame: NSRect(x: 212, y: 3, width: 44, height: 17))
        percent.alignment = .right
        percent.tag = percentTag
        let play = NSButton(image: NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Play test sound")!,
                            target: target, action: #selector(StatusMenuTarget.testAlertClicked))
        play.isBordered = false
        play.toolTip = "Play test sound"
        play.contentTintColor = .controlAccentColor
        play.frame = NSRect(x: 262, y: 1, width: 24, height: 24)
        [title, slider, percent, play].forEach(row.addSubview)
        item.view = row
        return item
    }
}
