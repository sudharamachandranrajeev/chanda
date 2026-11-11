#!/usr/bin/env bash
# Installs Chanda for the current user (no root needed).
#
#   ./install.sh                 # from an unpacked release tarball
#   scripts/install-linux.sh     # from a source checkout, after `flutter build linux --release`
#   ./install.sh --uninstall     # removes the app; your data stays
#
# The app goes to ~/.local/lib/chanda, a launcher to ~/.local/bin/chanda and a
# menu entry to ~/.local/share/applications. Your encrypted data lives in
# ~/.local/share/dev.brahma.chanda and its key in the desktop keyring; neither
# is touched by installing, upgrading or uninstalling.
set -euo pipefail

app_id=dev.brahma.chanda
dest="$HOME/.local/lib/chanda"
bin="$HOME/.local/bin/chanda"
desktop="$HOME/.local/share/applications/$app_id.desktop"
icon="$HOME/.local/share/icons/hicolor/512x512/apps/$app_id.png"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${1:-} == --uninstall ]]; then
  rm -rf "$dest"
  rm -f "$bin" "$desktop" "$icon"
  command -v update-desktop-database >/dev/null && update-desktop-database -q "$(dirname "$desktop")" || true
  echo "Chanda removed. Your data is still in ~/.local/share/$app_id."
  exit 0
fi

# A release tarball has the app next to this script; a checkout has it in build/.
if [[ -x $here/chanda ]]; then
  bundle="$here"
  png="$here/chanda.png"
else
  root="$(cd "$here/.." && pwd)"
  bundle="$root/build/linux/x64/release/bundle"
  png="$root/branding/chanda-512.png"
  if [[ ! -x $bundle/chanda ]]; then
    echo "No build found. Run: flutter build linux --release" >&2
    exit 1
  fi
fi

# The database key is kept in the desktop keyring through libsecret.
# grep reads all input (no -q): under pipefail an early exit would fail the pipe.
if ! ldconfig -p 2>/dev/null | grep libsecret-1.so.0 >/dev/null; then
  echo "Warning: libsecret is not installed. Install it (e.g. libsecret / libsecret-1-0) or Chanda cannot store its key." >&2
fi
# The -wpe build uses the system's WPE WebKit (2.52 or later) for the in-app browser.
if [[ -f $bundle/lib/libflutter_inappwebview_linux_plugin.so ]]; then
  if ! ldconfig -p 2>/dev/null | grep libWPEWebKit-2.0.so.1 >/dev/null; then
    echo "Warning: WPE WebKit is not installed, so Chanda will not start. Install it (Arch, Omarchy: sudo pacman -S wpewebkit)." >&2
  elif command -v pacman >/dev/null && command -v vercmp >/dev/null; then
    wpe_version=$(pacman -Q wpewebkit 2>/dev/null | awk '{print $2}')
    if [[ -n $wpe_version && $(vercmp "$wpe_version" 2.52) -lt 0 ]]; then
      echo "Warning: WPE WebKit $wpe_version is older than 2.52. Update it: sudo pacman -Syu wpewebkit" >&2
    fi
  fi
fi
if command -v busctl >/dev/null &&! busctl --user list 2>/dev/null | grep org.freedesktop.secrets >/dev/null; then
  echo "Note: no keyring service is running right now (GNOME Keyring or KWallet). Chanda needs one when it starts." >&2
fi

# Copy beside the old install, then swap, so a failed copy leaves it working.
mkdir -p "$(dirname "$dest")"
staging="$(mktemp -d "$dest.new.XXXXXX")"
chmod 755 "$staging"
trap 'rm -rf "$staging"' EXIT
cp -a "$bundle/chanda" "$bundle/lib" "$bundle/data" "$staging/"
rm -rf "$dest.old"
[[ -e $dest ]] && mv "$dest" "$dest.old"
mv "$staging" "$dest"
rm -rf "$dest.old"
trap - EXIT

mkdir -p "$(dirname "$bin")" "$(dirname "$desktop")" "$(dirname "$icon")"
ln -sf "$dest/chanda" "$bin"
[[ -f $png ]] && cp "$png" "$icon"
cat >"$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Chanda
GenericName=Shopping assistant
Comment=Your shopping vault, price alerts and price comparison
Exec=$dest/chanda
Icon=$app_id
Terminal=false
Categories=Utility;
Keywords=shopping;wishlist;prices;alerts;compare;deals;
StartupWMClass=$app_id
DESKTOP
command -v update-desktop-database >/dev/null && update-desktop-database -q "$(dirname "$desktop")" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "Chanda installed. Start it from your app menu or run: chanda"
