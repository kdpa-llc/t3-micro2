# Contributing to T3 Micro Bridge

Thank you for your interest in contributing to T3 Micro Bridge! We welcome contributions from the community.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Your environment: macOS version, pad firmware, T3 Code version, and `t3-micro2 version`
- The output of `t3-micro2 doctor` and `t3-micro2 status`

The bridge's log holds the titles of your threads. Take them out before you paste it, and never paste a token.

### Suggesting Features

We welcome feature suggestions! Please open an issue with:

- A clear description of the feature
- The problem it solves
- Any examples or use cases
- Optional: proposed implementation approach

### Pull Requests

1. **Fork the repository** and create your branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clear, concise commit messages
   - Follow the existing code style
   - Update the README, and `docs/keymap.html` if a key changes
   - Add a check to `Sources/SelfTest.swift` for logic that needs no pad

3. **Test your changes**
   ```bash
   npm run lint
   npm test
   ```

4. **Submit a pull request**
   - Provide a clear description of the changes
   - Reference any related issues
   - Say what you tested on a real pad, and with which firmware
   - Ensure CI checks pass

## Development Setup

You need a Mac with Apple's command line tools (`xcode-select --install`). Node is only for the commit-message hook.

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/t3-micro2.git
cd t3-micro2

# Install the dev tools and the commit-message hook
npm install

# Build and install from the checkout
./t3-micro2 setup
```

After a change, `./t3-micro2 build` rebuilds the app and restarts the bridge. The app is signed with an identity kept on your Mac, so the Accessibility permission stays across builds.

To build without touching your install, point the build at another folder. This is what the smoke test does:

```bash
WORK=$(mktemp -d)
T3_MICRO_APP="$WORK/T3 Micro Bridge.app" T3_MICRO_SIGN=adhoc T3_MICRO_BUNDLE_ID=us.kdpa.t3-micro-bridge.dev ./t3-micro2 build
"$WORK/T3 Micro Bridge.app/Contents/MacOS/t3-micro-bridge" --self-test
```

The binary has a few arguments for development. Except for the self-test, they read your real T3 Code and pad:

| Argument            | What it does                                                                        |
| ------------------- | ----------------------------------------------------------------------------------- |
| `--self-test`       | Runs the checks that need neither a pad nor T3 Code                                 |
| `--threads`         | Prints the six threads the keys would show                                          |
| `--shortcuts`       | Prints the key press the bridge sends for each T3 Code command                      |
| `--spaces --verbose` | Prints each T3 server and the `t3` program its token comes from                    |
| `--device`          | Prints the pad's firmware and layers. Stop the bridge first                         |
| `--layer-install --dry-run` | Says what setup would change on the pad, and changes nothing                |
| `--layer-rewrite`   | Reads the pad's keymap and writes the same bytes back, to test the write path       |
| `--verbose`         | Logs every message to and from the pad                                              |

There is no argument that makes the app press a key, on purpose: the app holds the Accessibility permission, and any program on the Mac could start it. Test keys on a real pad.

## Code Style

- Swift is compiled with plain `swiftc` in Swift 5 mode, with no packages and no Xcode project, so Apple's command line tools are enough
- The `t3-micro2` script is Bash (macOS ships Bash 3.2, so no Bash 4 features) and passes `shellcheck -S warning`
- Follow existing patterns and conventions
- Keep functions focused and small
- Add comments for anything a reader would otherwise have to work out
- Write user-facing messages in plain words and say what to do next
- Anything written to the pad is saved as a backup first, and checked against the pad's own checksum after
- The app holds the Accessibility permission. Don't add a way to make it press keys from outside, and keep the check that T3 Code is in front

## Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and changelog generation. The `commit-msg` hook checks each message, and CI checks every commit in a pull request.

### Commit Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

- **feat**: A new feature (triggers minor version bump)
- **fix**: A bug fix (triggers patch version bump)
- **perf**: A performance improvement (triggers patch version bump)
- **docs**: Documentation changes (triggers patch version bump)
- **refactor**: Code refactoring without feature changes (triggers patch version bump)
- **build**: Changes to how the app is built, signed or packaged (triggers patch version bump)
- **style**: Code style changes (formatting, no functional changes)
- **test**: Adding or updating tests
- **ci**: Changes to CI configuration
- **chore**: Other changes
- **revert**: Reverts a previous commit (triggers patch version bump)

### Breaking Changes

For a change that breaks existing installs or moves a key, add `BREAKING CHANGE:` in the commit body or append `!` after the type. This triggers a major version bump:

```
feat!: move STOP to the knob

BREAKING CHANGE: row 3, third key is now FORK. Press the knob twice to stop a run
```

### Examples

```bash
# Feature
feat(keys): open the next waiting thread from one key

# Bug fix
fix(pad): keep the T3 layer when the Input app is in front

# Documentation
docs(readme): explain the two key orders

# Breaking change
feat!: keep settings in ~/.config/t3-micro2

BREAKING CHANGE: setup must be run again after updating
```

### Guidelines

- Use imperative mood ("Add feature" not "Added feature")
- Reference issues in the footer: `Resolves #123` or `Closes #456`
- Keep subject line under 72 characters
- Separate subject from body with a blank line
- Use body to explain what and why, not how

## Project Structure

```
t3-micro2/
├── t3-micro2                  # The command: setup, status, doctor, uninstall
├── Sources/
│   ├── main.swift             # Entry point and the one-shot commands
│   ├── Bridge.swift           # Layer watching, lights, what each key does
│   ├── Micro.swift            # The pad: USB reports, calls, files
│   ├── T3.swift               # T3 Code: tokens, thread states, key order
│   ├── Actions.swift          # Key presses and button presses in T3 Code
│   ├── Shortcuts.swift        # T3 Code's shortcuts, and the one for stop
│   ├── Keymap.swift           # Works out the T3 layer from the pad's keymap
│   ├── SetupTool.swift        # Adds and restores the layer, with backups
│   ├── OrderedJSON.swift      # JSON that writes back exactly what it read
│   ├── Support.swift          # Paths, log, settings
│   └── SelfTest.swift         # Checks that need neither a pad nor T3 Code
├── docs/keymap.html           # The 3D key map
├── tests/smoke.sh             # Builds into a temporary folder, runs the self-test
├── scripts/                   # Release-notes check
├── .releaserc.json            # semantic-release configuration
└── commitlint.config.js       # Commit message rules
```

## Testing

### Running Tests

```bash
# Lint the scripts (shellcheck)
npm run lint

# Build into a temporary folder and run the self-test
npm test
```

The smoke test touches nothing outside its temporary folder. The self-test covers the JSON reader and writer, the keymap change (against the exact file a pad ran with), the shortcut reader, thread states and both key orders.

### What CI Covers

CI lints the scripts, checks that release notes can be generated and that commit messages follow Conventional Commits, and checks what goes into the npm package. A macOS job then installs that package like a user would, builds the app from it and runs the self-test. While the repository is private the macOS job runs only when someone starts the workflow by hand.

### Manual Testing

CI has no pad and no T3 Code. So far the bridge has run on one pad (firmware 0.6.3), on macOS 27 with Apple silicon, with a US keyboard layout. Other firmware, Intel Macs, older macOS versions and other layouts are untested, and reports are welcome.

For a change to keys, lights or setup, test on a real pad and say so in the pull request:

- `t3-micro2 setup` on a fresh Mac, and again over an existing install
- Each key you changed, in simple and in advanced mode
- Codex on its own layer before and after a visit to the T3 layer
- The Input app in front, then behind

## Documentation

When adding features or changing functionality:

- Update README.md
- Update `docs/keymap.html` when a key changes: its `CONTROLS` list holds every label and description
- Update `t3-micro2 help`
- Don't edit CHANGELOG.md by hand: semantic-release writes it from the commit messages

## Releases

There is no release yet. Once there is, releases are automatic: after CI passes on `main`, semantic-release picks the next version from the commit messages, publishes it to npm, creates a GitHub release and updates CHANGELOG.md. The version lives in `package.json` only: the build writes it into the app. See [PUBLISHING.md](PUBLISHING.md).

## Community

- Be respectful and inclusive
- Follow our [Code of Conduct](CODE_OF_CONDUCT.md)
- Help others in discussions and issues
- Share your key maps and setups!

## Questions?

Feel free to open an issue for questions or join the discussion in existing issues.

Thank you for contributing! 🎉
