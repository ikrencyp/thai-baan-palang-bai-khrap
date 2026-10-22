# Changelog

Each release gets a `## x.y.z` heading and a few short `- ` lines. The update dialog shows the first four.

## 1.0.2
- The updater and get.sh install a release only if the maintainer signed it, so a replaced download is refused even when its checksum matches
- Release builds run in a job with no write access, and a new structure check keeps process, network and admin code in a few named files

## 1.0.1
- One Alerts menu: when it fires (lid and lock, how often, which power) and what it sounds like (sound, play count, volume) are in the same place
- The Alert sound menu stands alone only on a Mac where lid and lock detection is not available
- The leaf heartbeat follows how hard the Mac is working: a calm beat when idle, a harder and faster one under load
- A structure check in CI keeps process, network and admin code in a few named files, and pins every workflow action to a commit hash

## 1.0.0
- First public release: a menu bar switch that keeps your Mac awake with the lid shut or the screen locked
- Stay awake for a set time, until a date and time, or until you turn it off. Quitting puts normal sleep back
- Plays a warning on the Mac's own speaker if the lid is shut or the screen is locked while it is awake
- Can go back to normal sleep on low battery or when the charger comes out (you choose, off by default). Checks GitHub Releases for updates
