# Changelog

Each release gets a `## x.y.z` heading and a few short `- ` lines. The update dialog shows the first four.

## 1.2.2
- The percent in the update window follows the real download now: it counts the bytes that have arrived against the size GitHub announces, climbs step by step to 100%, and keeps spinning instead of showing a made-up number when the size is not known

## 1.2.1
- What's new has a new layout: a header with the app icon and your version, one card per release with the changes in a clear list, and a tinted "Where to find it" row with the menu path and the Show me where button
- How to use has a new layout too: numbered quick-start steps, a card that explains each leaf, and one card per menu item with its own icon
- A new install opens How to use the first time, so you see how the app works; an update still opens What's new
- Turn the screen off when locked or closed is off on a new install now; an install that already ran keeps it as it was

## 1.2.0
- New Settings > Leaf colour: one colour for the leaf on the charger and one for the battery, each from nine named colours or any colour code such as #FF8800; the golden flame stays golden
- The colours show everywhere the leaf is drawn or described: the menu bar, the Staying awake row at the top of the menu and How to use; an alert shows the battery colour
- Installing an update shows how much of the download is in, as a bar with a percent that only goes up, so you can see it is really loading
- Show me where in What's new opens the menu with the way marked: the items on the path are in bold, the ones to open next say Open and the new item says New
- Find it: Settings > Leaf colour

## 1.1.1
- Installing an update shows its three steps (Download, Prepare, Install and restart) in the progress window, the finished ones ticked, so you see how far it is
- Includes 1.1.0: Power rules > Screen > Look present at the screen keeps you from showing as away in chat apps while Keep awake is on (off by default)
- Find it: Power rules > Screen > Look present at the screen

## 1.1.0
- New Power rules > Screen > Look present at the screen (off by default): while Keep awake is on, the Mac does not look idle to other apps, so a chat app does not show you as away when you step out; switch it off and everything goes back to how it was
- It sends one tiny mouse event with no movement a minute, so macOS asks once for the Accessibility permission; nothing is sent while Keep awake is off, or while the lid is shut or the screen is locked with the screen-off rule on
- What's new now carries a short tour: a release can say where its new thing sits in the menu, with a Show me button that opens the menu
- How to use has a card for the new switch
- Find it: Power rules > Screen > Look present at the screen

## 1.0.4
- The leaf is green while the Mac is charging and red when it is not, and the flame around it is golden in both cases
- The same colours show in the menu header and in the How to use window

## 1.0.3
- Fixed the countdown beside the icon freezing and jumping: it waited a fixed second after each tick, so the time drifted and skipped; it now redraws at the moment the second changes
- The countdown counts every second in every energy choice; Power saver and Automatic on battery used to show whole minutes that changed once a minute

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
