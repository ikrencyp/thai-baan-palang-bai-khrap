# Using TBPK

The first time the app starts after a new install it opens **How to use**, so you see what it can do. After an update it opens **What's new** once instead.

Click the leaf in the menu bar to open the menu. This page goes through it, one part at a time.

## Stay awake for

Pick how long the Mac should stay awake: 30 minutes, 1, 2, 4, 8 or 12 hours, or until you turn it off yourself.

For anything else, choose **At a date and time...**. There are two tabs:

- **For how long**: type any length from 1 to 9,999 minutes, hours, days or weeks.
- **At a time**: pick a day (today, tomorrow or a date) and a time.

The window tells you in plain words what will happen, for example "Tomorrow 08:00". You can only pick a time that is still ahead. Press Return to confirm, Escape to cancel.

The three lengths you pick most often show up under **Often used**, so one click repeats them. **Clear often used** wipes the list.

## Alerts

One menu holds both halves of the alert: when it fires, and what it sounds like. On a Mac without lid and lock detection the sound settings stand alone under **Alert sound**.

### When it fires

Here is the usual accident: you turn it on, drop the Mac in your bag, and it runs until the battery is flat. The alert is there to stop that. It plays a sound when all three of these are true:

1. The lid is shut with no extra monitor plugged in, or the screen is locked.
2. The power matches your choice: **Only on battery** (the default) or **On battery or plugged in**.
3. Keep awake is on.

If you close the lid while a monitor is plugged in, that is normal desk use, so it stays quiet. A locked screen still gets the alert.

Lifting the lid for a quick look does not set it off, because it waits a moment first. **How often**: Once (the default), Off, or every 5, 15 or 30 minutes. The app also writes down what happened (for example "Lid closed 14:32 on battery"), so you can read it later even if the battery died.

### What it sounds like

Open **Sound** to pick from two lists:

- **My sounds**: your own files (AIFF, WAV, MP3, M4A, AAC or CAF, up to 30 seconds each). **Add sound files...** copies them into the app's folder, so the originals can move or go.
- **Mac sounds**: the system alert (the default) and the sounds already on your Mac.

Picking a sound does not play it, so nothing makes noise by surprise. The play button on the **Alert volume** row plays it once. **Play how many times** can be 1, 3, 5, 10 or 20, remembered for each sound or shared by all.

The warning comes out of the Mac's own speaker, not Bluetooth headphones or AirPods. With wired headphones plugged in, the app switches the Mac to its speaker for the alert and back after. If macOS refuses to switch, the alert would reach the headphones, so the app plays nothing louder than your own volume.

If your Mac is muted or very quiet, the app turns the speaker up so you can hear the alert, then puts it back. It never turns anything down. If you change the volume yourself while the alert plays, your change wins. If the app is killed in the middle, it fixes the volume the next time it starts.

## Power rules

- **Go back to normal sleep when**: the battery drops below 20% or 10%, or the charger comes out. The default is Never. When it fires, the app plays the alert once and the menu tells you why.
- **Low Power Mode while on battery** (off by default): while the Mac is kept awake, it also runs in Low Power Mode on battery. The old setting is put back afterwards. Switching it on asks for your password once and adds the same no-password file as "Allow, no password after this" (see [Permissions](permissions.md)), even if you chose to be asked every time.
- **Keep the screen on while awake** (on by default): the screen does not go dark by itself. Turn it off and the Mac follows its normal screen timeout, but still stays awake.
- **Look present at the screen** (off by default): see below.
- **Turn the screen off when locked or closed** (off on a new install; an install that already ran keeps it on): the screen goes dark when you lock it or shut the lid.

### Look present at the screen

Chat apps such as Teams or Slack show you as away after a few minutes without mouse or keyboard input. Keep awake does not count as input, so you can show as away while the Mac is working for you. This switch fixes that.

1. Click the leaf, open **Power rules**, and choose **Look present at the screen** under **Screen**.
2. macOS asks once to let the app control your computer. Open **System Settings > Privacy & Security > Accessibility** and turn on Thai Baan Palang Bai Khrap. Without it the switch does nothing.
3. Turn on Keep awake and walk away. Every minute the app sends one mouse-moved event that moves nothing, so the Mac never looks idle.
4. To stop, choose the same item again. Nothing is sent and idle time counts as before.

It only runs while Keep awake is on and the screen is held. It stays quiet while the lid is shut or the screen is locked with **Turn the screen off when locked or closed** on. After an update, **What's new** shows where to find it, with a **Show me where** button that opens the menu.

## Leaf colour

**Settings > Leaf colour** has two colours: **On the charger** (green by default) and **On battery** (red by default). The leaf shows the first while the Mac is charging and the second while it runs on battery or an alert is showing. The flame around it stays golden.

1. Click the leaf, open **Settings > Leaf colour**, then **On the charger** or **On battery**.
2. Pick one of nine colours, or **Custom colour...** and type a code such as `#FF8800` (`FF8800` and the short `#F80` work too). A wrong code is explained and asked again.
3. The menu bar, the **Staying awake** row and **How to use** change at once.

## Energy use

**Settings > Energy use** decides how hard the app works to look alive. **Automatic** is the default: calm on the charger, still on battery.

| Choice | What you see | How often it checks |
|---|---|---|
| Automatic | On the charger: a slow heartbeat every few seconds. On battery, in Low Power Mode, or with Reduce Motion on: a still leaf | every 15 seconds on the charger, every 30 seconds otherwise |
| Full performance | The leaf beats all the time | every 5 seconds |
| Power saver | A still leaf, no animation | every 30 seconds |

Nothing is drawn while the screen is asleep. Measured on one Mac on the charger: about 4.8% CPU on Full performance, 0.5% on Automatic, 0.0% on Power saver. That is one Mac on one afternoon, so check your own with `top`.

## Quit

When you quit, the Mac goes back to how it was. If the app was the one that turned sleep off, it turns it back on. If sleep was already off before the app started, or something else did it, the app leaves it alone. If it cannot restore sleep, the app tells you why and asks whether to stay open or quit anyway. If you quit anyway, the Mac keeps running until you turn sleep back on yourself.

The app never turns Keep awake back on by itself when it starts. It only remembers your settings. If you left a timer running, the countdown continues only when sleep is still off and the end time has not passed.
