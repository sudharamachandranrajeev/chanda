#!/usr/bin/env bash
# Packs the Linux release bundle into a tarball for a GitHub release.
#
#   scripts/linux-tarball.sh <version>        dist/Chanda-<version>-linux-x64.tar.gz
#   scripts/linux-tarball.sh <version> wpe    dist/Chanda-<version>-linux-x64-wpe.tar.gz
#
# Run after `flutter build linux --release`. The plain tarball is built without
# the web view (packages/no_linux_webview); the wpe one links against the
# system's WPE WebKit 2.52+ and bundles none of it.
set -euo pipefail

version=${1:?usage: linux-tarball.sh <version> [wpe]}
variant=${2:-}
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

suffix=linux-x64
[[ $variant == wpe ]] && suffix=linux-x64-wpe
dir="chanda-$version-$suffix"
bundle=build/linux/x64/release/bundle
[[ -x $bundle/chanda ]] || { echo "No build in $bundle. Run: flutter build linux --release" >&2; exit 1; }

plugin=$bundle/lib/libflutter_inappwebview_linux_plugin.so
if [[ $variant == wpe ]]; then
  [[ -f $plugin ]] || { echo "The wpe tarball needs the web view plugin; this build has none." >&2; exit 1; }
else
  [[ ! -f $plugin ]] || { echo "The plain tarball must be built without the web view (packages/no_linux_webview)." >&2; exit 1; }
fi
if compgen -G "$bundle/lib/libWPEWebKit*" >/dev/null; then
  echo "The bundle carries its own WPE WebKit; it must use the system's." >&2
  exit 1
fi

rm -rf "$dir"
mkdir -p dist "$dir"
cp -r "$bundle/." "$dir/"
cp branding/chanda-512.png "$dir/chanda.png"
cp scripts/install-linux.sh "$dir/install.sh"
cp LICENSE THIRD_PARTY_NOTICES.md "$dir/"

if [[ $variant == wpe ]]; then
  needs="GTK 3, libsecret, WPE WebKit 2.52 or later (the in-app browser; on Arch
and Omarchy: sudo pacman -S wpewebkit) and a running keyring (GNOME Keyring
or KWallet), which holds the database key."
else
  needs="GTK 3, libsecret and a running keyring (GNOME Keyring or KWallet), which
hold the database key. This build has no in-app browser: shops open in your
own browser. On Arch or Omarchy, take the -wpe download instead."
fi
cat >"$dir/README.txt" <<EOF
Chanda for Linux (x86-64). Needs $needs

  ./install.sh              adds Chanda to your app menu (no root needed)
  ./install.sh --uninstall  removes it; your data stays
  ./chanda                  runs it from this folder without installing

Your data: ~/.local/share/dev.brahma.chanda (encrypted).
EOF

tar czf "dist/Chanda-$version-$suffix.tar.gz" "$dir"
rm -rf "$dir"
echo "dist/Chanda-$version-$suffix.tar.gz"
