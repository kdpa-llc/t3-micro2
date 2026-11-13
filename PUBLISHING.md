# Publishing Guide

This guide explains how T3 Micro Bridge is released to npm as [`t3-micro2`](https://www.npmjs.com/package/t3-micro2), the same name as the command.

## Prerequisites

1. **npm Account**: the package is owned by the `moscaverd` npm account
2. **npm Credential**: none is stored. The package trusts this repository's Release workflow (npm trusted publishing)
3. **GitHub Credential**: the workflow's own token, or a `RELEASE_TOKEN` Actions secret when `main` requires pull requests

## Automated Publishing

The project uses [semantic-release](https://github.com/semantic-release/semantic-release) for automated versioning and publishing.

### How It Works

1. **Commit with Conventional Commits**: Use the conventional commit format. The `commit-msg` hook (husky and commitlint, set up by `npm install`) checks it, and CI checks it on pull requests
   ```bash
   git commit -m "feat: add new feature"
   git commit -m "fix: resolve bug"
   ```

2. **Merge to main**: The `Release` workflow runs after the `CI` workflow passes on `main`
   ```bash
   git push origin main
   ```

3. **Automated Process**:
   - Analyzes commits to determine version bump
   - Generates CHANGELOG.md
   - Creates GitHub release
   - Publishes to npm
   - Commits the version and changelog back to `main`, marked `[skip ci]`

The Release workflow starts after CI succeeds, so a version is published after the macOS job installed the package, built the app from it and ran the self-test. Starting the workflow by hand skips that wait, so do it only for a commit CI has already passed.

The project's own scripts (lint, the release-notes check, the build) run in CI, which has no token. The Release job runs nothing of the project but semantic-release.

The version is kept in `package.json` only. `t3-micro2 version` reads it, and the build writes it into the app.

Version 0.1.0 was published by hand to claim the name, and is tagged `v0.1.0`. Every version after it comes from the workflow.

### npm Credential

There is no npm token. On npmjs.com the package has a trusted publisher: GitHub Actions, repository `kdpa-llc/t3-micro2`, workflow `release.yml`. The Release job asks GitHub for a short-lived identity token (`id-token: write`), and npm accepts a publish from exactly that workflow.

```bash
npm trust list t3-micro2      # shows the trusted publisher
```

Trusted publishing needs npm 11.5.1 or later, which the workflow's Node 24 brings. A release from a fork, another workflow file or another repository is refused by npm.

### GitHub Credential

`@semantic-release/git` finishes the release by pushing the generated
`CHANGELOG.md`, `package.json` and `package-lock.json` directly to `main`.

By default the Release job does this with the workflow's own token, which
GitHub creates for that run and which reaches only this repository.

A ruleset that requires pull requests on `main` would refuse that push. The
other KDPA repositories solve it with an organization secret, `RELEASE_TOKEN`,
whose owner has a bypass in the ruleset. To do the same here, add `t3-micro2`
to the secret's **Repository access** under **Organization settings → Secrets
and variables → Actions**. The workflow uses the secret whenever it is there.
The PAT behind it should reach nothing it does not need: the release job hands
it to semantic-release and its plugins.

### Branch Protection

`main` has a ruleset that blocks force pushes and deletion. It does not require
pull requests, because the workflow's own token could not push the release
commit then. With `RELEASE_TOKEN` shared (see above), the ruleset can also:

- require pull requests for normal changes;
- require the CI checks (`Lint` and `Build and self-test (macOS)`); and
- grant the user that owns the release PAT an `Always allow` bypass.

### Commit Types and Version Bumps

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat:` | Minor (0.x.0) | `feat: show seven threads` |
| `fix:` | Patch (0.1.x) | `fix: keep the layer after the Input app saves` |
| `perf:`, `refactor:`, `docs:`, `build:`, `revert:` | Patch (0.1.x) | `docs: explain the two key orders` |
| `test:`, `ci:`, `chore:`, `style:` | None | `ci: add an Intel job` |
| `BREAKING CHANGE:` | Major (1.0.0) | `feat!: move STOP to the knob` |

The first breaking change makes version 1.0.0. Until the bridge has run on more pads and Macs, avoid one.

### Release Branches

- `main` - Production releases
- `next` - Next version (pre-release)
- `beta` - Beta releases (pre-release)
- `alpha` - Alpha releases (pre-release)

## Manual Publishing (Not Recommended)

A manual publish needs a person: the npm account has a security key as its second factor, so `npm login --auth-type=web` and `npm publish` each print a link that the owner opens and approves.

```bash
npm login --auth-type=web
npm run lint && npm test
npm publish
git tag v<version> && git push origin v<version>
```

Tag what you publish, or semantic-release will try to publish the same version again.

## Verifying a Release

```bash
npm view t3-micro2 version
npm install -g t3-micro2
t3-micro2 version
```
