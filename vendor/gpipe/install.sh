#!/usr/bin/env bash
# {{GPIPE_GENERATED_BY}}
set -euo pipefail

REPO="{{REPO}}"
VERSION="{{VERSION}}"
BINARY="{{BINARY}}"
INSTALL_NAME="{{INSTALL_NAME}}"

# Parse --user flag
USER_INSTALL=false
for arg in "$@"; do
  case "$arg" in
    --user) USER_INSTALL=true ;;
  esac
done

# Detect OS and architecture
_OS="$(uname -s)"
_ARCH="$(uname -m)"

case "$_OS" in
  Linux)  OS="linux" ;;
  Darwin) OS="darwin" ;;
  *)
    echo "error: unsupported OS: $_OS" >&2
    exit 1
    ;;
esac

case "$_ARCH" in
  x86_64)         ARCH="amd64" ;;
  aarch64|arm64)  ARCH="arm64" ;;
  *)
    echo "error: unsupported architecture: $_ARCH" >&2
    exit 1
    ;;
esac

PLATFORM="${OS}_${ARCH}"

# Validate detected platform against supported list (baked in at generation time)
{{SUPPORTED_PLATFORMS_BLOCK}}

# Asset name map: platform -> download filename (baked in at generation time)
{{ASSET_MAP_BLOCK}}

ASSET_NAME="${ASSET_NAMES[$PLATFORM]}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET_NAME}"
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums.txt"

{{PRE_INSTALL_HOOK}}

# Download binary and checksums
_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$_TMPDIR"' EXIT

echo "Downloading ${BINARY} ${VERSION} for ${PLATFORM}..."
if command -v curl > /dev/null 2>&1; then
  curl -fsSL -o "${_TMPDIR}/${ASSET_NAME}" "${DOWNLOAD_URL}"
  curl -fsSL -o "${_TMPDIR}/checksums.txt" "${CHECKSUMS_URL}"
elif command -v wget > /dev/null 2>&1; then
  wget -q -O "${_TMPDIR}/${ASSET_NAME}" "${DOWNLOAD_URL}"
  wget -q -O "${_TMPDIR}/checksums.txt" "${CHECKSUMS_URL}"
else
  echo "error: curl or wget is required" >&2
  exit 1
fi

# Verify SHA256 checksum
echo "Verifying checksum..."
EXPECTED_CHECKSUM="$(grep "^[a-f0-9]*  ${ASSET_NAME}$" "${_TMPDIR}/checksums.txt" | awk '{print $1}')"
if [ -z "$EXPECTED_CHECKSUM" ]; then
  echo "error: checksum not found for ${ASSET_NAME} in checksums.txt" >&2
  rm -f "${_TMPDIR}/${ASSET_NAME}"
  exit 1
fi

if command -v sha256sum > /dev/null 2>&1; then
  ACTUAL_CHECKSUM="$(sha256sum "${_TMPDIR}/${ASSET_NAME}" | awk '{print $1}')"
elif command -v shasum > /dev/null 2>&1; then
  ACTUAL_CHECKSUM="$(shasum -a 256 "${_TMPDIR}/${ASSET_NAME}" | awk '{print $1}')"
else
  echo "error: sha256sum or shasum is required" >&2
  exit 1
fi

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
  echo "error: checksum mismatch for ${ASSET_NAME}" >&2
  echo "  expected: $EXPECTED_CHECKSUM" >&2
  echo "  actual:   $ACTUAL_CHECKSUM" >&2
  rm -f "${_TMPDIR}/${ASSET_NAME}"
  exit 1
fi

echo "Checksum verified."

# Install binary
INSTALL_DIR="/usr/local/bin"
if [ "$USER_INSTALL" = "true" ]; then
  INSTALL_DIR="${HOME}/.local/bin"
  mkdir -p "$INSTALL_DIR"
  install -m 0755 "${_TMPDIR}/${ASSET_NAME}" "${INSTALL_DIR}/${INSTALL_NAME}"
elif ! install -m 0755 "${_TMPDIR}/${ASSET_NAME}" "${INSTALL_DIR}/${INSTALL_NAME}" 2>/dev/null; then
  echo "Insufficient permissions for system install. Installing to ~/.local/bin instead."
  USER_INSTALL=true
  INSTALL_DIR="${HOME}/.local/bin"
  mkdir -p "$INSTALL_DIR"
  install -m 0755 "${_TMPDIR}/${ASSET_NAME}" "${INSTALL_DIR}/${INSTALL_NAME}"
fi

# BEGIN_BLOCK:COMPLETION_BASH
# Install bash completions
if "${INSTALL_DIR}/${INSTALL_NAME}" completion bash > /dev/null 2>&1; then
  if [ "$USER_INSTALL" = "true" ]; then
    mkdir -p "${HOME}/.bash_completion.d"
    "${INSTALL_DIR}/${INSTALL_NAME}" completion bash > "${HOME}/.bash_completion.d/${BINARY}"
    echo "Installed bash completions to ~/.bash_completion.d/${BINARY}"
  elif "${INSTALL_DIR}/${INSTALL_NAME}" completion bash 2>/dev/null | install -m 0644 /dev/stdin "/etc/bash_completion.d/${BINARY}" 2>/dev/null; then
    echo "Installed bash completions to /etc/bash_completion.d/${BINARY}"
  else
    mkdir -p "${HOME}/.bash_completion.d"
    "${INSTALL_DIR}/${INSTALL_NAME}" completion bash > "${HOME}/.bash_completion.d/${BINARY}"
    echo "Installed bash completions to ~/.bash_completion.d/${BINARY}"
  fi
else
  echo "Warning: bash completion generation failed, skipping" >&2
fi
# END_BLOCK:COMPLETION_BASH

# BEGIN_BLOCK:COMPLETION_ZSH
# Install zsh completions
if "${INSTALL_DIR}/${INSTALL_NAME}" completion zsh > /dev/null 2>&1; then
  if [ "$USER_INSTALL" = "true" ]; then
    mkdir -p "${HOME}/.zfunc"
    "${INSTALL_DIR}/${INSTALL_NAME}" completion zsh > "${HOME}/.zfunc/_${BINARY}"
    echo "Installed zsh completions to ~/.zfunc/_${BINARY}"
  elif "${INSTALL_DIR}/${INSTALL_NAME}" completion zsh 2>/dev/null | install -m 0644 /dev/stdin "/usr/share/zsh/site-functions/_${BINARY}" 2>/dev/null; then
    echo "Installed zsh completions to /usr/share/zsh/site-functions/_${BINARY}"
  else
    mkdir -p "${HOME}/.zfunc"
    "${INSTALL_DIR}/${INSTALL_NAME}" completion zsh > "${HOME}/.zfunc/_${BINARY}"
    echo "Installed zsh completions to ~/.zfunc/_${BINARY}"
  fi
else
  echo "Warning: zsh completion generation failed, skipping" >&2
fi
# END_BLOCK:COMPLETION_ZSH

# BEGIN_BLOCK:COMPLETION_FISH
# Install fish completions
if "${INSTALL_DIR}/${INSTALL_NAME}" completion fish > /dev/null 2>&1; then
  if [ "$USER_INSTALL" = "true" ]; then
    mkdir -p "${HOME}/.config/fish/completions"
    "${INSTALL_DIR}/${INSTALL_NAME}" completion fish > "${HOME}/.config/fish/completions/${BINARY}.fish"
    echo "Installed fish completions to ~/.config/fish/completions/${BINARY}.fish"
  elif "${INSTALL_DIR}/${INSTALL_NAME}" completion fish 2>/dev/null | install -m 0644 /dev/stdin "/usr/share/fish/completions/${BINARY}.fish" 2>/dev/null; then
    echo "Installed fish completions to /usr/share/fish/completions/${BINARY}.fish"
  else
    mkdir -p "${HOME}/.config/fish/completions"
    "${INSTALL_DIR}/${INSTALL_NAME}" completion fish > "${HOME}/.config/fish/completions/${BINARY}.fish"
    echo "Installed fish completions to ~/.config/fish/completions/${BINARY}.fish"
  fi
else
  echo "Warning: fish completion generation failed, skipping" >&2
fi
# END_BLOCK:COMPLETION_FISH

{{POST_INSTALL_HOOK}}

# PATH verification and repair (user-local installs only)
if [ "$USER_INSTALL" = "true" ]; then
  if ! echo ":${PATH}:" | grep -q ":${INSTALL_DIR}:"; then
    _MODIFIED_FILES=""
    for _rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
      if [ -f "$_rc_file" ]; then
        echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "$_rc_file"
        _MODIFIED_FILES="${_MODIFIED_FILES} ${_rc_file}"
      fi
    done
    if [ -n "$_MODIFIED_FILES" ]; then
      echo "Added ${INSTALL_DIR} to PATH in${_MODIFIED_FILES}"
      echo "Restart your shell or run: source ~/.bashrc"
    fi
  fi
else
  if ! command -v "$INSTALL_NAME" > /dev/null 2>&1; then
    echo "Warning: ${INSTALL_NAME} is not reachable via PATH" >&2
  fi
fi

echo "Successfully installed ${INSTALL_NAME} ${VERSION}"
