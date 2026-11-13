# Changelog

All notable changes to this project will be documented in this file. See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 0.1.0 (2026-11-12)

First version, installed from a checkout before releases were published to npm.

### Features

* **lights:** the six thread keys show the state of six T3 Code threads, in the colors the ChatGPT app uses for Codex; the ring shows the most urgent state of every open thread
* **order:** keys follow urgency (`priority`) or the T3 Code sidebar (`sidebar`)
* **keys:** thread keys open their thread; NEXT, APPROVE, STOP, NEW, MIC, SETTLE and SEND act on T3 Code; the knob steps through threads and picks a model
* **modes:** simple mode has one action per key; advanced mode adds hold actions and the joystick; hold the knob to switch
* **sources:** threads from more than one T3 server on the same Mac; `t3-micro2 spaces` lists, adds and removes them, and asks each server for its token with the program that runs it
* **shortcuts:** the bridge presses the shortcuts in T3 Code's own keybindings file, so changed shortcuts keep working
* **pad:** the bridge holds the pad only on the T3 layer, and lets go while the Input app is in front, so Codex and the Input app keep working
* **setup:** `t3-micro2 setup` builds and signs the app, adds the T3 layer to the pad after a backup, adds a stop shortcut to T3 Code, and starts the bridge at login
* **commands:** `status`, `doctor`, `threads`, `keymap`, `logs`, `spaces`, `layer show|install|restore`, `build`, `start`, `stop`, `restart`, `uninstall [--all]`
* **signing:** a self-signed identity kept on the Mac, so the Accessibility permission survives updates
* **docs:** a 3D key map, `docs/keymap.html`
