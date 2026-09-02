<p align="center">
  <img src="images/logo.png" width="280" alt="Pyra logo" />
</p>

<h1 align="center">Pyra</h1>

<p align="center">
  <b>A native package manager for jailbroken Apple TV</b><br>
  Browse repos. Install tweaks. Never leave the couch.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-tvOS_15+-black?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/jailbreak-palera1n_rootful-0A84FF?style=flat-square" />
  <img src="https://img.shields.io/badge/swift-5-FA7343?style=flat-square&logo=swift&logoColor=white" />
  <img src="https://img.shields.io/badge/license-TBD-lightgrey?style=flat-square" />
</p>

---

## The problem

There's no proper on-TV package manager for palera1n on Apple TV. The recommended workflow is `apt` over SSH, or PurePKG's tvOS build. Both work — but neither was *designed* for a TV remote.

**Pyra** is built from scratch for the big screen: focus-driven navigation, horizontal repo browsing à la App Store, and full tweak management without ever touching a terminal.

---

## ✦ What it does

| | |
|---|---|
| 🏠 **Home** | One horizontal row per repo — scroll, focus, select. Feels like the App Store, not a package list. |
| 🔍 **Search** | Unified search across every added source. |
| 📦 **Install / Remove** | Tap to install, see live `dpkg` output, done. Dependencies are checked *before* install — missing packages are flagged, not silently broken. |
| 🔄 **Updates** | Installed tweaks with a newer version get a badge. One tap to update. |
| ➕ **Add repos** | Supports nested (Procursus-style `dists/…`) and flat layouts, auto-detected. Multi-repo quick-add lets you punch in several sources without re-opening the keyboard. |
| ⚙️ **Settings** | Language (RU / EN), download cache, repo list reset, diagnostic log, device info. |

---

## Requirements

```
Apple TV 4K (1st gen, A10X) or any palera1n-supported model
palera1n rootful jailbreak
tvOS 15.0+
```

---

## Installation

<details>
<summary><b>Option 1 — APT repo (recommended)</b></summary>

Add this source in PurePKG or any APT-compatible manager:

```
https://fauxly.github.io/
```

Then install Pyra from the package list.

</details>

<details>
<summary><b>Option 2 — direct .deb</b></summary>

1. Grab the latest `.deb` from [**Releases**](../../releases).
2. Copy to device and run:

```bash
dpkg -i com.fixstricks.atlas_*.deb
```

</details>

<details>
<summary><b>Option 3 — palera1n loader</b></summary>

Pyra ships a [`loader.json`](loader.json) config. Point the palera1n loader app at this file's raw URL to get Pyra as an install option during bootstrap — works alongside PurePKG.

</details>

---

## Under the hood

A few things that came up while building this — might be useful if you're working on tvOS jailbreak tooling:

**Privilege escalation** — rootful palera1n mounts the root filesystem `nosuid`, breaking classic `su` / `tsu`. Pyra uses the persona-based `posix_spawn` API (`posix_spawnattr_set_persona_np` + friends) — the same approach [PurePKG](https://github.com/Lrdsnow/PurePKG) uses.

**Custom tab bar** — `UITabBarController` on tvOS doesn't let you insert arbitrary elements (like a persistent back button) into its bar. The entire navigation shell is a hand-built `UIViewController` container.

**Repo format detection** — Pyra tries the standard nested layout first (`dists/{dist}/{comp}/binary-{arch}/Packages`), then falls back to flat (`Packages` at repo root). No user configuration needed.

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
