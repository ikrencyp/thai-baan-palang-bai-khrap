# Thai Baan Palang Bai Khrap (TBPK)

**Close the lid. Lock the screen. Your Mac keeps working.**

A small free app that sits in the menu bar. Turn it on, and your Mac stays awake even with the lid shut. Turn it off, and the Mac sleeps like normal again.

Version 1.0.4 · macOS 13 or newer · Apple Silicon and Intel · MIT License

## Why I made it

You start something long. A download, a build, an AI agent working through your code. You close the laptop and walk off to a meeting. When you come back, the Mac fell asleep halfway and the job stopped.

That is the whole reason. TBPK keeps the Mac going until the job is done, whether the lid is open or shut, the screen locked or not.

The idea comes from [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704), a Mac App Store app that made "keep my Mac awake" a one-click thing. TBPK is a separate project and has no link to Amphetamine or its author.

## What it does

- Sits in the menu bar. No dock icon.
- The leaf is the switch. An outline leaf means normal sleep. A green leaf in a golden flame means the Mac is being kept awake on the charger; the leaf turns red when it is not charging. It lights up with a flash when you turn it on, then beats slowly like a heart.
- Stay awake for 30 minutes, 1, 2, 4, 8 or 12 hours, any time you type, until a date and time, or until you turn it off.
- Plays a warning sound if the Mac is awake with the lid shut or the screen locked, so you do not forget it in your bag. The sound comes from the Mac's own speaker, not from Bluetooth headphones or AirPods.
- Can go back to normal sleep by itself when the battery runs low or you pull the charger (you choose; it is off until you turn it on).
- When you quit, it puts the Mac back how it found it.

## Install

### The easy way

Open Terminal and paste this:

```bash
curl -fsSL https://raw.githubusercontent.com/ikrencyp/thai-baan-palang-bai-khrap/main/get.sh | bash
```

It downloads the latest version, checks the file is not damaged and was signed by the maintainer, puts the app in Applications and opens it. The script is short, so read [get.sh](get.sh) first if you like.

Why Terminal? The app is not signed with a paid Apple certificate, so macOS complains about files downloaded in a browser. A file downloaded with `curl` does not get that complaint.

### From the download page

1. Download `TBPK-<version>.dmg` from the [Releases page](https://github.com/ikrencyp/thai-baan-palang-bai-khrap/releases).
2. Open it and run **install.sh** from inside (drag it into a Terminal window). It sets things up and opens the app.

If you drag the app into Applications yourself and macOS refuses to open it ("cannot be opened because the developer cannot be verified"), run this once in Terminal:

```bash
xattr -dr com.apple.quarantine "/Applications/Thai Baan Palang Bai Khrap.app"
```

**Do you need `sudo`? Usually no.** If you dragged the app in yourself, your account owns it and the command just works. Add `sudo` in front only if it answers `Permission denied`, which means root owns the app (for example it was copied with `sudo`).

**What happens when you run it:** macOS stamps files that come from the internet with a "quarantine" label, and that label is what makes it refuse to open the app. The command removes that label from this one app and nothing else. It prints nothing when it works. Then the app opens normally. The app itself is not changed, and you do not need to do this again, except after you download a new copy in a browser. Nothing is wrong with your Mac either way: the label is a normal macOS safety check, and you are telling macOS you trust this app.

On macOS 15 or newer there is another way. Try to open the app once, then go to System Settings > Privacy & Security and press **Open Anyway**.

### Build it yourself

You need Xcode or the Command Line Tools, nothing else.

```bash
git clone https://github.com/ikrencyp/thai-baan-palang-bai-khrap.git
cd thai-baan-palang-bai-khrap
./build.sh      # runs the tests and builds dist/TBPK-1.0.4.dmg
./install.sh    # installs it
```

An app you built on your own Mac opens without any fuss.

## Using it

Click the leaf in the menu bar. The top switch turns keep-awake on and off. Right-click the leaf to flip it without opening the menu.

The first time you turn it on, the app explains that it needs your Mac's admin password and gives you a choice:

- **Allow, no password after this.** You type the password once. After that it never asks.
- **Ask for my password each time.** It asks every time you switch.
- **Cancel.**

Every menu item is explained in [Using TBPK](docs/usage.md).

## What it touches on your Mac

An honest list, so nothing surprises you:

- It runs the built-in macOS command `pmset`: to turn sleep off and on, to read the state, to darken the screen when you lock it, and, only if you switch on Low Power Mode, to set that. Changing sleep and Low Power Mode needs admin rights.
- If you pick "no password after this" (or later switch on Low Power Mode, which needs the same file), it adds one small file, `/etc/sudoers.d/tbpk-<your name>`. That file lets your account run four exact `pmset` commands without a password, and nothing else.
- It may turn the speaker volume up for the warning sound, then puts it back.
- It checks GitHub for a new version every few hours. It does not install one unless you switch that on.

The full story, and how to remove all of it, is in [Permissions](docs/permissions.md).

## Uninstall

Dragging the app to the Trash leaves the sudoers file behind, so use the script:

```bash
./uninstall.sh --dry-run    # shows what it would do
./uninstall.sh              # does it
```

It quits the app, puts normal sleep back, and removes the rule, the settings and the app.

## More reading

| Page | What is in it |
|---|---|
| [Using TBPK](docs/usage.md) | Every menu item, the alerts, sounds, power rules |
| [Updates](docs/updates.md) | How a new version is found and installed |
| [Permissions](docs/permissions.md) | The password prompt and the sudoers file |
| [How it works](docs/architecture.md) | For people reading the code |
| [Releasing](docs/releasing.md) | How a new version gets published |
| [Contributing](CONTRIBUTING.md) | Help is welcome |
| [Security](SECURITY.md) | Found a problem? Tell me privately |

## Good to know

- It is not on the App Store and cannot be. Running `pmset` as admin rules that out.
- It is not notarized yet. Notarizing needs a paid Apple Developer account. Until then, the install steps above are how you get past macOS.
- The timer lives inside the app. If the Mac restarts or you force-quit the app, the sleep setting stays as it was until you change it.
- macOS's own `caffeinate` cannot do this job. It stops idle sleep, but not the sleep that comes from closing the lid.

## License

MIT. See [LICENSE](LICENSE).
