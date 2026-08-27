#!/bin/sh
set -eu

version=$(cat VERSION)
xxhash_version=0.8.3
xxhash_sha256=aae608dfe8213dfd05d909a57718ef82f30722c392344583d3f39050c7f29a80
signing_fingerprint=9FEF112DCE19A0DC7E882CB81BB24997A8535F6F
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

download() {
  curl --retry 5 --retry-all-errors --connect-timeout 20 -fsSLo "$1" "$2"
}

download "$work/rsync.tar.gz" \
  "https://download.samba.org/pub/rsync/src/rsync-$version.tar.gz"
download "$work/rsync.tar.gz.asc" \
  "https://download.samba.org/pub/rsync/src/rsync-$version.tar.gz.asc"

export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
curl --retry 5 --retry-all-errors --connect-timeout 20 -fsSL \
  "https://keys.openpgp.org/vks/v1/by-fingerprint/$signing_fingerprint" \
  | gpg --batch --import
gpg --batch --verify "$work/rsync.tar.gz.asc" "$work/rsync.tar.gz"

download "$work/xxhash.tar.gz" \
  "https://github.com/Cyan4973/xxHash/archive/refs/tags/v$xxhash_version.tar.gz"
echo "$xxhash_sha256  $work/xxhash.tar.gz" | sha256sum -c -

tar -C "$work" -xf "$work/xxhash.tar.gz"
make -C "$work/xxHash-$xxhash_version" libxxhash.a
install -Dm644 "$work/xxHash-$xxhash_version/libxxhash.a" "$work/deps/lib/libxxhash.a"
install -Dm644 "$work/xxHash-$xxhash_version/xxhash.h" "$work/deps/include/xxhash.h"

tar -C "$work" -xf "$work/rsync.tar.gz"
cd "$work/rsync-$version"
configure_features=
if test "$(uname -m)" = x86_64; then
  configure_features="--enable-roll-simd --enable-roll-asm"
fi
CPPFLAGS="-I$work/deps/include" \
LDFLAGS="-static -L$work/deps/lib -Wl,--build-id=none" \
  ./configure CFLAGS="-Os -fno-ident" \
    --with-included-popt --with-included-zlib $configure_features
make -j"$(getconf _NPROCESSORS_ONLN)"
strip rsync

features=$(./rsync --version)
echo "$features" | grep -q 'ACLs'
echo "$features" | grep -q 'xattrs'
echo "$features" | grep -q 'openssl-crypto'
echo "$features" | grep -q 'xxh128 xxh3 xxh64'
echo "$features" | grep -q 'zstd lz4 zlibx'
file rsync | grep -q 'statically linked'
! readelf -l rsync | grep -q INTERP

mkdir -p "$work/smoke/source" "$work/smoke/destination"
echo static-rsync > "$work/smoke/source/file"
./rsync -aAX "$work/smoke/source/" "$work/smoke/destination/"
cmp "$work/smoke/source/file" "$work/smoke/destination/file"

arch=$(uname -m)
if test "$arch" = x86_64; then
  echo "$features" | grep -q 'SIMD-roll, asm-roll'
fi
artifact="rsync-$version-linux-$arch"
mkdir -p "$OLDPWD/dist/$artifact"
install -m755 rsync "$OLDPWD/dist/$artifact/rsync"
./rsync --version > "$OLDPWD/dist/$artifact/features.txt"
apk info -v > "$OLDPWD/dist/$artifact/packages.txt"
tar -C "$OLDPWD/dist" -czf "$OLDPWD/dist/$artifact.tar.gz" "$artifact"
cd "$OLDPWD/dist"
sha256sum "$artifact.tar.gz" > "$artifact.tar.gz.sha256"
