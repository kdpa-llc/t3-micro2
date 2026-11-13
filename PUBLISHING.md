# Publishing Guide

This guide explains how T3 Micro Bridge is released. Releases go to npm as `t3-micro2`, the same name as the command.

There is no release yet. Until the first one, people install from a checkout, and `package.json` is marked `"private": true` so nothing reaches npm by mistake.

## Prerequisites

1. **npm Account**: the package is published by the `moscaverd` npm account
2. **npm Credential**: an `NPM_TOKEN` Actions secret, or npm trusted publishing (see below)
3. **GitHub Credential**: a `RELEASE_TOKEN` Actions secret

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

The workflow has two jobs. `Check` runs the project's own scripts and gets no token. `Release` gets the tokens and runs only semantic-release.

The version is kept in `package.json` only. `t3-micro2 version` reads it, and the build writes it into the app.

### The First Release

1. Share `RELEASE_TOKEN` and `NPM_TOKEN` with this repository (see below).
2. Remove `"private": true` from `package.json` in a commit named `build: publish to npm as t3-micro2`. A `build` commit makes a release.
3. Check that `npm view t3-micro2 version` shows the new version before the README tells anyone to install from npm. The name is not reserved until then.

The first release is `1.0.0`, semantic-release's default when no earlier version tag exists.

### Branch Protection and the Release Commit

`@semantic-release/git` finishes the release by pushing the generated
`CHANGELOG.md`, `package.json` and `package-lock.json` directly to `main` as
the user authenticated by the `RELEASE_TOKEN` Actions secret. The repository
therefore protects `main` with a **repository ruleset**, not a classic branch
protection rule.

The `main` ruleset must:

- require pull requests for normal changes;
- require the CI checks (`Lint` and `Build and self-test (macOS)`);
- block force pushes and branch deletion; and
- grant the **moscaverd** user, which owns the release PAT, an `Always allow`
  bypass.

When configuring the ruleset through the API, use `actor_type: "User"` and
`actor_id: 1047574` for `moscaverd`.

### GitHub Release Credential

The release needs an Actions secret named `RELEASE_TOKEN`. The `kdpa-llc`
organization keeps `RELEASE_TOKEN` and `NPM_TOKEN` as organization secrets
shared with selected repositories: add `t3-micro2` to each one's **Repository
access** under **Organization settings → Secrets and variables → Actions**.
The PAT behind `RELEASE_TOKEN` needs access to this repository, with permission
to read and write repository contents, and should reach nothing it does not
need: the release job hands it to semantic-release and its plugins.

### npm Credential

semantic-release publishes with `NPM_TOKEN` when it's set. Once the package
exists on npm, trusted publishing (OIDC) can replace the token: on npmjs.com,
open the `t3-micro2` package settings, add a trusted publisher for GitHub
Actions with repository `kdpa-llc/t3-micro2` and workflow `release.yml`, then
remove this repository's access to `NPM_TOKEN`. The Release workflow already
runs Node 24 with an npm version that supports it and grants `id-token: write`.

### Commit Types and Version Bumps

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat:` | Minor (1.x.0) | `feat: show seven threads` |
| `fix:` | Patch (1.0.x) | `fix: keep the layer after the Input app saves` |
| `perf:`, `refactor:`, `docs:`, `build:`, `revert:` | Patch (1.0.x) | `docs: explain the two key orders` |
| `test:`, `ci:`, `chore:`, `style:` | None | `ci: add an Intel job` |
| `BREAKING CHANGE:` | Major (x.0.0) | `feat!: move STOP to the knob` |

### Release Branches

- `main` - Production releases
- `next` - Next version (pre-release)
- `beta` - Beta releases (pre-release)
- `alpha` - Alpha releases (pre-release)

## Verifying a Release

```bash
npm view t3-micro2 version
npm install -g t3-micro2
t3-micro2 version
```
