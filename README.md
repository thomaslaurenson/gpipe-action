# gpipe-action

A composite GitHub Action that generates `install.sh`, `install.ps1`, and `checksums.txt` for GitHub releases using [`gpipe`](https://github.com/thomaslaurenson/gpipe).

## Usage

```yaml
- uses: thomaslaurenson/gpipe-action@v1
  with:
    version: ${{ github.ref_name }}
```

### Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `version` | Yes | `${{ github.ref_name }}` | Release version tag. Validated as semver before use. |
| `repo` | No | `${{ github.repository }}` | GitHub repository in `owner/repo` format. |
| `config` | No | `.gpipe.yml` | Path to config file relative to repo root. |

### Example release workflow

```yaml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-24.04
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v6

      - name: Build binaries
        run: make dist   # or your build step

      - uses: thomaslaurenson/gpipe-action@v1
        with:
          version: ${{ github.ref_name }}

      - name: Create release
        run: |
          gh release create "${{ github.ref_name }}" \
            ./dist/* install.sh install.ps1 checksums.txt
        env:
          GH_TOKEN: ${{ github.token }}
```

### Example `.gpipe.yml`

```yaml
binary: mycli

platforms:
  linux_amd64: ./dist/mycli-linux-x86_64
  linux_arm64: ./dist/mycli-linux-aarch64
  darwin_amd64: ./dist/mycli-macos-x86_64
  darwin_arm64: ./dist/mycli-macos-arm64
  windows_amd64: ./dist/mycli-windows-x86_64.exe
  windows_arm64: ./dist/mycli-windows-aarch64.exe

hooks:
  post-sh:  .gpipe/post-install.sh

completions:
  bash: true
  zsh:  true
```

All other configuration (binary, platforms, hooks, completions) lives in `.gpipe.yml`. See the [`gpipe` README](https://github.com/thomaslaurenson/gpipe) for the full config reference.

## Version pinning

Use `@v1` to always receive non-breaking updates automatically. Breaking changes are released under `@v2`.

```yaml
uses: thomaslaurenson/gpipe-action@v1       # recommended, receives patch/minor fixes
uses: thomaslaurenson/gpipe-action@v1.2.0   # pinned to exact release
```

## Vendored gpipe source

The `vendor/gpipe/` directory contains a vendored copy of the `gpipe` source. The current vendored version is recorded in `vendor/gpipe/GPIPE_VERSION`. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to sync a new version.
