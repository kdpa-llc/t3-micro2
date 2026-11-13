# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version            | Supported          |
| ------------------ | ------------------ |
| The latest release | :white_check_mark: |
| Anything older     | :x:                |

## Reporting a Vulnerability

We take the security of T3 Micro Bridge seriously. If you discover a security vulnerability, please follow these steps:

### How to Report

**Please do NOT open a public issue.**

Instead, report it privately through GitHub: open the [Security tab](https://github.com/kdpa-llc/t3-micro2/security) and choose **Report a vulnerability**.

### What to Include

When reporting a vulnerability, please include:

- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact
- Suggested fix (if you have one)
- Your macOS version, pad firmware and T3 Code version

Never include a token, and take thread titles out of any log you attach.

### Response Timeline

- **Acknowledgment**: We aim to acknowledge receipt within 48 hours
- **Initial Assessment**: We'll provide an initial assessment within 5 business days
- **Updates**: We'll keep you informed of our progress
- **Resolution**: We aim to release a fix as soon as possible, depending on complexity

### Disclosure Policy

- Please give us reasonable time to fix the issue before public disclosure
- We'll credit you in the security advisory (unless you prefer to remain anonymous)
- We'll coordinate with you on the disclosure timeline

## Security Best Practices

When using T3 Micro Bridge:

### For Users

1. **Keep Updated**: Run `git pull` and `t3-micro2 setup` now and then
2. **Look Before You Approve**: APPROVE presses the newest Approve button in the T3 Code window. Read the request first
3. **Give Accessibility to the Bridge Only**: The permission belongs to T3 Micro Bridge, not to your terminal or your agent
4. **Clean Logs Before Sharing**: The log holds the titles of your threads
5. **Remove It Fully**: `t3-micro2 uninstall --all` revokes the tokens and deletes the signing identity

### For Contributors

1. **No Secrets in Code**: Never commit tokens, logs or keymap backups
2. **No Secrets in Output**: Commands must not print tokens
3. **Read-Only Tokens**: The bridge asks T3 Code for the `orchestration:read` scope only. A change that needs more must say why
4. **Back Up Before Writing**: Anything written to the pad or to T3 Code's files is saved first

## Known Security Considerations

### The Accessibility Permission

- macOS's Accessibility permission lets an app send key presses to, and press buttons in, any other app. The bridge needs it for every action except opening a thread and starting a new one
- Key presses go to whichever app is in front. The bridge brings T3 Code to the front, checks that it is the front app, waits a moment, checks again, and only then sends the key press. If T3 Code is not in front within a second and a half, nothing is sent. A window that takes the front in the instant after the last check would still receive it
- The app takes no command that makes it press a key, so another program can't borrow its permission that way. It is signed with the hardened runtime, so macOS refuses to load other code into it
- APPROVE and its hold action, Decline, look through the T3 Code window for a button with that name, from the bottom up, and press the first one found
- SEND presses Return in T3 Code. It sends whatever is in the composer

### The Signing Identity

- macOS ties the Accessibility permission to the app's identifier and signature. An ad hoc signature changes with every build, so setup makes a self-signed code-signing certificate and signs every build with it
- The certificate and its key are in a keychain of their own, `~/Library/Application Support/T3MicroBridge/signing.keychain-db`. Its password is in a file next to it, readable only by you. Setup does not touch your login keychain. On macOS 27 the new keychain did not appear in the keychain search list; `security list-keychains` shows yours
- Any program that can read your files can sign with this identity. An app signed with it, and given the bridge's identifier, would inherit the Accessibility permission without a new question
- `t3-micro2 uninstall --all` deletes the keychain and the Accessibility entry

### T3 Code Tokens

- For each T3 data folder in `t3Homes`, the bridge runs `t3 auth session issue` with the scope `orchestration:read`, a 90 day life and the label "Micro 2 bridge". It uses the `t3` program that runs that server, because servers on one Mac can be of different versions
- `t3-micro2 spaces add` makes the bridge read one more T3 server on the Mac, and `spaces remove` ends its session there. Thread titles of every server it reads go to the same log
- The bridge runs the `t3` program it finds through a data folder. `spaces add` therefore refuses a folder that belongs to someone else or that others can write to
- The scope is read-only by its name. What it covers is decided by T3 Code, not by the bridge. The bridge uses it to read thread state. Starting, stopping and changing a thread go through the T3 Code window
- A token is sent only to the address in that folder's `server-runtime.json`, and only if the address is on this Mac and the server's process is alive
- Tokens are stored in `~/Library/Application Support/T3MicroBridge/` in files readable only by you. The bridge asks for a new one when a server rejects the old one
- `t3-micro2 uninstall --all` revokes the sessions with that label and deletes the files. It needs the app for that: if the app was removed first, it says so and the sessions end by themselves after 90 days
- The bridge reads thread titles and states. It does not read messages

### The Pad

- While the pad is on the T3 layer, the bridge opens it with exclusive access, so other programs can't read its vendor interface. It releases the pad on any other layer and while the Input app is in front
- Setup writes the pad's `keymap.json` once, to add the T3 layer. The file from before is saved in `~/Library/Application Support/T3MicroBridge/backups`, and the write is checked against the pad's own SHA-1 checksum of the file
- The pad's protocol and T3 Code's local endpoint are not documented by their makers, so an update to either can break the bridge

### What Stays on Your Mac

- The bridge has no network listener and sends nothing to the internet. It talks to the pad over USB and to the T3 servers named in each data folder's `server-runtime.json`
- The log, `~/Library/Logs/T3MicroBridge/bridge.log`, holds thread titles and key presses. It is cut off at 2 MB, with one older file kept
- `status.json`, which `t3-micro2 status` reads, holds counts and states but no titles
- The key map page, `docs/keymap.html`, is a plain web page. When you open it, your browser loads three.js from cdnjs and fonts from Google Fonts

### T3 Code's Keybindings

- T3 Code has no shortcut for stopping a run. Setup adds one, ⌘⌥X, to `~/.t3/userdata/keybindings.json`, after saving the file. If that key is taken, setup adds nothing and says so
- `t3-micro2 uninstall --all` removes that one entry, if it is unchanged

## Security Updates

Security updates will be:

- Released as patch versions (e.g., 0.1.1)
- Documented in CHANGELOG.md
- Announced in the release notes
- Tagged with [SECURITY] in commit messages

## Contact

For security concerns, please use GitHub's private vulnerability reporting on this repository.

Thank you for helping keep T3 Micro Bridge secure!
