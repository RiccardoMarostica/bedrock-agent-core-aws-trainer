# Contributing

## Release and Changelog Guidelines

This project follows **[Semantic Versioning (SemVer)](https://semver.org/)** for release management.
Every release must be tracked and documented through the changelog system.

---

## Release Procedure

### 1. Sign the release with npm

This automatically updates:
- The **version** in `package.json`
- The **changelog** with changes included in the release

Use one of the following commands based on the impact of changes:

```bash
npm version patch   # for bugfixes or minor changes
npm version minor   # for new backward-compatible features
npm version major   # for breaking changes
```

### 2. Push the tag to Git

```bash
git push --follow-tags
```

### 3. Create the release on GitHub

1. Go to the **Releases** section of the repository on GitHub.
2. Create a new release using the tag that was just pushed.
3. Copy the automatically generated changelog section into the release body.

---

## When to Sign a Release

A release is **required** in the following cases:

- At the **end of each development sprint**.
- When performing a **production deployment**.
- When deploying to **AWS environments** (staging or production).

In all other cases (local testing, internal experiments, unconsolidated fixes), a release is **not required**.

---

## Best Practices

- Only sign releases on **main branches** (`main` or `release/*`).
- Verify all tests pass before signing:
  ```bash
  npm test
  ```
- Never manually modify the version in `package.json` — use `npm version` only.
- Ensure you have **push permissions for tags** and **release creation permissions** on GitHub.
- Update technical documentation if necessary before signing.

---

## Example Workflow

```bash
# 1. Update main branch
git pull origin main

# 2. Run tests
npm test

# 3. Sign the release (updates changelog and package.json)
npm version minor

# 4. Push the tag to Git
git push --follow-tags

# 5. Create the release on GitHub
# (copy the auto-generated changelog section into the release body)
```

---

## Recommended Tools

- [`conventional-changelog`](https://github.com/conventional-changelog/conventional-changelog) — automatic changelog generation.
- [`commitlint`](https://github.com/conventional-changelog/commitlint) — consistent commit message style.
- [`standard-version`](https://github.com/conventional-changelog/standard-version) — integrated alternative for versioning and changelog.
