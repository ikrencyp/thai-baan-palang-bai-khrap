# How TBPK works

Notes for anyone reading the code.

## The basics

- The app reads the sleep state from `pmset -g`. On a Mac where `disablesleep` was never set, the `SleepDisabled` line is missing instead of showing 0. Missing means off.
- It checks the power source, not `IsCharging`. A Mac plugged in at a full battery says `IsCharging = No`, which would wrongly look like "unplugged".
- The lock state works the same way: `CGSSessionScreenIsLocked` is missing while the screen is unlocked.
- The menu bar item is built with AppKit, not SwiftUI's `MenuBarExtra`, because `MenuBarExtra` cannot see a right click.
- A speaker's volume control is not always in the same place. The same Mac once answered on two channels, and an hour later on the master control. So the code asks the device what it has, master first, and only writes to what answers.

## Folders

```
Sources/TBPK/
  App/       start-up and the menu bar item
  Power/     pmset, sudo, durations, quit rules, power limits
  Watch/     lid and lock detection, when to alert
  Sound/     alert sounds, your own sounds, volume, which speaker
  Icon/      the leaf drawing, its animation
  Menu/      the menu, one file per submenu, saved settings
  Dialogs/   About, How to use, What's new, date window, first-time question
  Update/    check GitHub, verified download, install
  Support/   clock text, login item, cleanup of leftover files
Tests/TBPKTests/   one file per test class
scripts/          icon maker, sudoers file scripts
docs/             these pages
```
