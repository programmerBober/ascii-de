#!/usr/bin/env bash
set -euo pipefail

REPO="${ASCII_DE_REPO:-programmerBober/ascii-de}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="release"
YES_MODE=0
BUILD_ONLY=0

usage() {
    cat <<'EOF'
Usage: ./install.sh [--release | --local | --dev] [--build-only] [--yes]

Modes:
  --release     Download latest verified .pkg.tar.zst from GitHub Releases and install via pacman (default)
  --local       Build and install locally from this git clone using makepkg -si
  --dev         Keep local developer checkout & ~/bin workflow intact without touching /usr packages
  --build-only  With --local, build .pkg.tar.zst without installing (passes makepkg -f)
  --yes, -y     Pass --noconfirm to pacman/makepkg
EOF
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --release)    MODE="release"; shift ;;
        --local)      MODE="local"; shift ;;
        --dev)        MODE="dev"; shift ;;
        --build-only) BUILD_ONLY=1; shift ;;
        --yes|-y)     YES_MODE=1; shift ;;
        -h|--help)    usage; exit 0 ;;
        *)
            echo "install.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

install_dev_mode() {
    echo "Configuring ASCII-DE developer mode in ${SCRIPT_DIR} (preserving ~/bin & ~/.config/ascii-de)..."
    export PATH="$HOME/.cargo/bin:$PATH"

    mkdir -p "$HOME/bin" "$HOME/.local/lib/ascii-de/bin" "$HOME/.config/ascii-de"

    cmake -B "$SCRIPT_DIR/compositor/build" -S "$SCRIPT_DIR/compositor" -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build "$SCRIPT_DIR/compositor/build" -j"$(nproc)"
    cargo build --manifest-path "$SCRIPT_DIR/backend/Cargo.toml" --release --locked

    install -Dm755 "$SCRIPT_DIR/compositor/build/ascii-de-compositor" "$HOME/bin/ascii-de-compositor"
    install -Dm755 "$SCRIPT_DIR/backend/target/release/ascii-de-backend" "$HOME/bin/ascii-de-backend"

    for script in ascii-de ascii-de-settings ascii-de-terminal ascii-de-x11-scroll-bridge ascii-de-update bt-menu ascii-de-autostart; do
        if [[ -f "$SCRIPT_DIR/bin/$script" ]]; then
            ln -sfn "$SCRIPT_DIR/bin/$script" "$HOME/bin/$script"
        fi
    done
    for shim in xclip xsel; do
        if [[ -f "$SCRIPT_DIR/bin/shims/$shim" ]]; then
            ln -sfn "$SCRIPT_DIR/bin/shims/$shim" "$HOME/.local/lib/ascii-de/bin/$shim"
        fi
    done

    local ver="0.1.0"
    [[ -f "$SCRIPT_DIR/VERSION" ]] && ver="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")"
    mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/ascii-de"
    cat > "${XDG_DATA_HOME:-$HOME/.local/share}/ascii-de/install-meta.json" <<EOF
{
  "version": "${ver}",
  "installMethod": "source",
  "repo": "${REPO}",
  "repoDir": "${SCRIPT_DIR}",
  "prefix": "${HOME}"
}
EOF

    echo "OK: Developer binaries built and linked in ~/bin (configs in ~/.config/ascii-de untouched)."
}

install_local_makepkg() {
    if ! command -v makepkg >/dev/null 2>&1; then
        echo "install.sh: makepkg not found (EndeavourOS/Arch required for --local)." >&2
        exit 1
    fi
    local pkg_dir="$SCRIPT_DIR/packaging/arch"
    if [[ ! -f "$pkg_dir/PKGBUILD" ]]; then
        echo "install.sh: PKGBUILD not found at $pkg_dir/PKGBUILD" >&2
        exit 1
    fi

    local ver="0.1.0"
    [[ -f "$SCRIPT_DIR/VERSION" ]] && ver="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")"
    local tar_name="ascii-de-${ver}.tar.gz"
    local stage_dir
    stage_dir="$(mktemp -d)"
    trap 'rm -rf "$stage_dir"' RETURN

    mkdir -p "$stage_dir/ascii-de-${ver}"
    tar -C "$SCRIPT_DIR" \
        --exclude='./.git' \
        --exclude='./compositor/build' \
        --exclude='./backend/target' \
        --exclude='./packaging/arch/src' \
        --exclude='./packaging/arch/pkg' \
        --exclude='*.pkg.tar.zst' \
        --exclude='*.tar.zst' \
        --exclude='*.tar.gz' \
        -cf - . | tar -C "$stage_dir/ascii-de-${ver}" -xf -
    tar -C "$stage_dir" -czf "$pkg_dir/$tar_name" "ascii-de-${ver}"

    local flags=(-f)
    if [[ "$BUILD_ONLY" -eq 0 ]]; then
        flags+=(-si --needed)
    fi
    [[ "$YES_MODE" -eq 1 ]] && flags+=(--noconfirm)

    # Allow rustup-installed toolchains when pacman's rust package is not installed
    if ! pacman -Q rust >/dev/null 2>&1 && [[ -x "$HOME/.cargo/bin/cargo" ]]; then
        export PATH="$HOME/.cargo/bin:$PATH"
        flags+=(-d)
    fi

    (cd "$pkg_dir" && makepkg "${flags[@]}")
    if [[ "$BUILD_ONLY" -eq 1 ]]; then
        echo "OK: ASCII-DE package built in $pkg_dir."
    else
        echo "OK: ASCII-DE built and installed via makepkg."
    fi
}

install_github_release() {
    if ! command -v pacman >/dev/null 2>&1; then
        echo "install.sh: pacman not found (EndeavourOS/Arch required for --release)." >&2
        exit 1
    fi
    for tool in curl jq sha256sum; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "install.sh: missing required tool '$tool'. Install it first (pacman -S $tool)." >&2
            exit 1
        fi
    done

    local api_resp
    api_resp="$(curl -fsSL --max-time 15 -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${REPO}/releases/latest")"

    local pkg_url pkg_name sum_url
    pkg_url="$(printf '%s' "$api_resp" | jq -r '.assets[]? | select(.name | test("^ascii-de-.*-x86_64\\.pkg\\.tar\\.zst$")) | .browser_download_url' | head -n 1)"
    pkg_name="$(printf '%s' "$api_resp" | jq -r '.assets[]? | select(.name | test("^ascii-de-.*-x86_64\\.pkg\\.tar\\.zst$")) | .name' | head -n 1)"
    sum_url="$(printf '%s' "$api_resp" | jq -r '.assets[]? | select(.name == "SHA256SUMS") | .browser_download_url' | head -n 1)"

    if [[ -z "$pkg_url" || -z "$sum_url" ]]; then
        echo "install.sh: latest release on ${REPO} lacks .pkg.tar.zst or SHA256SUMS." >&2
        exit 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    echo "Downloading ${pkg_name}..."
    curl -fsSL --max-time 120 -o "$tmp_dir/$pkg_name" "$pkg_url"
    curl -fsSL --max-time 15 -o "$tmp_dir/SHA256SUMS" "$sum_url"

    (cd "$tmp_dir" && grep -E "(^|[[:space:]]|\*)${pkg_name}$" SHA256SUMS | sha256sum -c -)

    local pac_flags=(-U --needed)
    [[ "$YES_MODE" -eq 1 ]] && pac_flags+=(--noconfirm)
    if [[ "$EUID" -eq 0 ]]; then
        pacman "${pac_flags[@]}" "$tmp_dir/$pkg_name"
    else
        sudo pacman "${pac_flags[@]}" "$tmp_dir/$pkg_name"
    fi

    echo "OK: ASCII-DE installed from GitHub Release (${pkg_name})."
}

case "$MODE" in
    dev)     install_dev_mode ;;
    local)   install_local_makepkg ;;
    release) install_github_release ;;
esac
