# Changelog

Each release gets a `## x.y.z` heading and a few short `- ` lines. The update dialog shows the first four.

## 1.3.3
- General bug fixes so the app runs more steadily
- Look present at the screen no longer nudges the pointer while it rests in the menu bar, on a screen edge or in a corner, which could open menus, float a tooltip over the screen and block the Spotlight shortcut

## 1.3.2
- General bug fixes so the app runs more steadily
- Look present at the screen now sends its input only when the Mac is idle, unlocked and lit, so it no longer swallows shortcuts or Spotlight and no longer parks the cursor in a corner
- Updating now shows four steps you can follow, Download, Prepare, Install and Reopen TBP, each on screen long enough to read, with a bar that keeps moving
- Update buttons and menu items say what they do (Update Now, Download and Update) and that only TBPK reopens, not your Mac

## 1.3.1
- Energy use moved into Power rules, and its choices now stay open: pick one, flip Set charger and battery separately, and the tick, the two power sources and the Right now line change on the spot instead of the menu closing
- The three screen switches (Keep the screen on while awake, Look present at the screen, Turn the screen off when locked or closed) moved into Settings > Screen
- Show animation is now Leaf motion, because it also sets the heartbeat and the power reading behind it, not only the power-up animation
- Switching Keep awake on and off in quick turns no longer leaves the icon showing the wrong state, and Low Power Mode on battery is set and given back one change at a time, so a fast on and off cannot leave it stuck; the state is also read again each time the menu opens
- What's new has a new look from this version on: the way to a new item is numbered steps with one Show me where button, and the menu marks the same numbers beside each step; earlier versions no longer have the button
- Find it: Power rules > Energy use
- Find it: Settings > Screen
- Find it: Settings > Leaf motion

## 1.2.5
- Energy use can be set separately for the charger and for battery: switch on Set charger and battery separately and each power source gets its own choice, used by itself when you plug or unplug; both are remembered when you switch back to one choice for both
- The leaf heartbeat now beats on battery and in Low Power Mode too, calm like on the charger; only Reduce Motion (and the Power saver choice) keeps the leaf still
- Find it: Settings > Energy use

## 1.2.4
- The leaf now crackles with lightning in time with its beat, the same bolts on the charger and on battery: pale blue with a white heart, flashing on the strong part of each beat
- Show me where walks the way one step at a time (Step 1 of 3, then 2, then 3) and then lights all of it; the last stop says Here and the ones to open say Open, and with Reduce Motion on the whole route stays lit and still
- The word New is gone from the menu and from the minutes row: What's new shows the way instead, and the way is orange and the last stop is green and says Here
- Find it: What’s new

## 1.2.3
- For how long takes hours and minutes together: a new And ... minutes row sits under Or any length, so 1 hour 30 minutes or 45 minutes is one choice, and the end time updates as you type
- The leaf burns with the gold aura and the lightning around it on battery too, the same as on the charger, and a leaf that does not beat (Power saver, Reduce Motion) holds that look steadily
- Show me where is clearer: the steps on the way are blue, the new item is orange, and the window it opens marks the new minutes row with an orange NEW tag
- Find it: Stay awake for > At a date and time…

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
