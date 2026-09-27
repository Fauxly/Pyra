<p align="center">
  <img src="images/logo.png" width="280" alt="Pyra logo" />
</p>

<h1 align="center">Pyra</h1>

<p align="center">
  <b>A native package manager for jailbroken Apple TV</b><br>
  Browse repos. Install tweaks. Never leave the couch.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-tvOS_17+-black?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/jailbreak-palera1n_rootful_%7C_rootless-0A84FF?style=flat-square" />
  <img src="https://img.shields.io/badge/swift-5-FA7343?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/license-TBD-lightgrey?style=flat-square" />
</p>

---

## The problem

There's no proper on-TV package manager for palera1n on Apple TV. The recommended workflow is `apt` over SSH, or PurePKG's tvOS build. Both work — but neither was *designed* for a TV remote.

**Pyra** is built from scratch for the big screen: focus-driven navigation, an Apple TV–style home screen, and full tweak management without ever touching a terminal. It runs on both **rootful** and **rootless** palera1n — the environment is detected automatically at launch.

---

## ✦ What it does

| | |
|---|---|
| 🏠 **Home** | Apple TV–style featured banners with backgrounds taken from package icons, a **New & updated** shelf, colorful category shortcuts, and a row per repo with a *See all* tile. |
| 🗂 **Categories** | Colored tiles with icons and package previews. Open one to get a grid grouped by source. |
| 🌐 **Sources** | Cards with repo icon, package count and live loading status. Open a repo to browse it grouped by category. Long-press to remove. |
| 📦 **Package page** | Blurred icon backdrop, big action button, screenshots and *What's new* from Sileo depictions, download and installed size, dependencies. |
| ⏳ **Install / Remove** | Step-by-step progress (download → install → verify → done). The raw `dpkg` log is one click away, missing dependencies are listed right in it. |
| ✅ **Installed** | Stats (installed, updates, disk usage) and tiles — tweaks and system packages shown separately. |
| 🔄 **Updates** | Badge on the tab, total download size, *old → new* version cards, **Update all** in one press. |
| 📺 **Top Shelf** | Put Pyra in the top row of the Home screen to see featured and new packages. Selecting one opens it straight in Pyra. |
| 🔍 **Search** | Unified search across every added source. |
| ⚙️ **Settings** | Language (RU / EN), auto-refresh on launch, download cache, repo list reset, respring, icon cache rebuild, diagnostic log, built-in updater. |

---

## Requirements

```
Apple TV 4K (1st gen, A10X) or any palera1n-supported model
palera1n jailbreak — rootful or rootless
tvOS 17.0+
```

---

## Installation

Pyra is published as **two packages** with the same ID (`com.fauxly.pyra`) — pick the one for your jailbreak:

| Jailbreak | Package | Installed to |
|---|---|---|
| Rootful | `com.fauxly.pyra_<version>_appletvos-arm64.deb` | `/Applications/Pyra.app` |
| Rootless | `com.fauxly.pyra_<version>_iphoneos-arm64.deb` | `/var/jb/Applications/Pyra.app` |

Not sure which one you have? If `/var/jb` exists on the device, it's rootless.

<details>
<summary><b>Option 1 — APT repo (recommended)</b></summary>

Add this source in Pyra, PurePKG or any APT-compatible manager:

```
https://fauxly.github.io/
```

Then install Pyra from the package list. APT picks the right package for your jailbreak automatically.

</details>

<details>
<summary><b>Option 2 — direct .deb</b></summary>

1. Grab the package for your jailbreak from [**Releases**](../../releases).
2. Copy it to the device and install:

**Rootful**
```bash
scp -O -P 44 com.fauxly.pyra_*_appletvos-arm64.deb root@<apple-tv-ip>:/var/mobile/
ssh -p 44 root@<apple-tv-ip> 'dpkg -i /var/mobile/com.fauxly.pyra_*_appletvos-arm64.deb && uicache -a'
```

**Rootless**
```bash
scp -O -P 44 com.fauxly.pyra_*_iphoneos-arm64.deb root@<apple-tv-ip>:/var/mobile/
ssh -p 44 root@<apple-tv-ip> 'export PATH=/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:$PATH; dpkg -i /var/mobile/com.fauxly.pyra_*_iphoneos-arm64.deb && uicache -a'
```

</details>

<details>
<summary><b>Option 3 — palera1n loader</b></summary>

Pyra ships a [`loader.json`](loader.json) config. Point the palera1n loader app at this file's raw URL to get Pyra as an install option during bootstrap — works alongside PurePKG.

</details>

<details>
<summary><b>Updating</b></summary>

**Settings → Check for updates** downloads the release package that matches your jailbreak and installs it.

> ⚠️ Pyra **1.0.84 and older** don't know about the two packages yet and may pick the wrong one on rootless. Update those through the APT repo or manually with the `iphoneos-arm64` package once — from 1.0.85 on the built-in updater handles it.

</details>

---

## Building

```bash
# 1. Release build (signing is done later by ldid)
xcodebuild -project Pyra.xcodeproj -scheme Pyra -configuration Release \
  -destination 'generic/platform=tvOS' CODE_SIGNING_ALLOWED=NO build

# 2. Package — produces both rootful and rootless .deb in output/
./build_deb.sh
```

`build_deb.sh` needs `dpkg-deb`, `rsync` and `ldid` (either on `PATH` or next to the script). It signs the app and the Top Shelf extension with their own entitlements (`entitlements.plist`, `entitlements-topshelf.plist`) and lays the same signed bundle out into both package variants.

---

## Under the hood

A few things that came up while building this — might be useful if you're working on tvOS jailbreak tooling:

**Rootful and rootless from one binary** — Pyra checks for `/var/jb` at launch and prefixes every POSIX path (`dpkg`, `apt`, `uicache`) accordingly. Only the packaging differs: `appletvos-arm64` into `/Applications` vs `iphoneos-arm64` into `/var/jb/Applications`, since the root filesystem is read-only on rootless.

**Same package, two architectures** — many tvOS tweaks are tagged `appletvos-arm64` yet work fine on rootless, so Pyra installs with `--force-architecture`. The flip side: when a repo carries one package in several architectures of the same version (like Pyra itself), Pyra keeps only the variant for the current environment, so it never force-installs the wrong one.

**Privilege escalation** — rootful palera1n mounts the root filesystem `nosuid`, breaking classic `su` / `tsu`. Pyra uses the persona-based `posix_spawn` API (`posix_spawnattr_set_persona_np` + friends) — the same approach [PurePKG](https://github.com/Lrdsnow/PurePKG) uses.

**Top Shelf without App Groups** — the extension runs sandboxed and has no network or catalog of its own. The app writes the featured list to `/var/mobile/Library/Caches/com.fauxly.pyra/TopShelf.json`, and the extension is signed with a read-only sandbox exception for exactly that folder. Items deep-link back via `pyra://package/<id>`.

**Custom tab bar** — `UITabBarController` on tvOS doesn't let you insert arbitrary elements (like a persistent back button) into its bar. The entire navigation shell is a hand-built `UIViewController` container.

**Repo format detection** — Pyra tries the standard nested layout first (`dists/{dist}/{comp}/binary-{arch}/Packages`), then falls back to flat (`Packages` at repo root). No user configuration needed.

**"New & updated" without dates** — APT indexes carry no publish dates, so Pyra remembers when it first saw each package version and treats the last seven days as fresh.

**Text input** — `UIAlertController` + `addTextField()` reliably hangs when the on-screen keyboard appears on this setup. A plain `UITextField` on a regular screen avoids the issue and supports "type from nearby iPhone" out of the box.

---

## Credits

- [**PurePKG**](https://github.com/Lrdsnow/PurePKG) by Lrdsnow — reference for the persona-spawn privilege escalation
- [**palera1n**](https://github.com/palera1n/palera1n) — the jailbreak that makes this possible
- [**Procursus**](https://github.com/ProcursusTeam/Procursus) — bootstrap and default repo

---

## Status

> 🚧 **Actively in development.** Issues, ideas and feedback welcome.

---

<p align="center">
  <sub>Made for the couch, not the command line.</sub>
</p>
