# static-rsync

[![Attested](https://img.shields.io/badge/Attested-brightgreen?style=flat&logo=github)](#verify-a-release)

Statically linked rsync for x86_64 and ARM64 Linux, built with musl and all default optional features: ACLs, xattrs, OpenSSL, xxHash, zstd, and lz4.

GitHub Actions checks the official rsync download directory daily. A new version is verified with the upstream signing key, built, smoke-tested, and published as an immutable GitHub release with checksums.

## Build locally

Docker is only used as an ephemeral Alpine build environment; this repository does not need a Dockerfile.

```sh
docker run --rm \
  --network host \
  -e HTTP_PROXY -e HTTPS_PROXY -e ALL_PROXY -e NO_PROXY \
  -e http_proxy -e https_proxy -e all_proxy -e no_proxy \
  -v "$PWD:/work" -w /work \
  alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce \
  sh -c 'apk add --no-cache build-base curl gnupg file binutils acl-dev acl-static attr-dev attr-static openssl-dev openssl-libs-static zstd-dev zstd-static lz4-dev lz4-static && ./build.sh'
```

Artifacts are written to `dist/`.

## Verify a release

GitHub automatically [attests immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases). Verify a downloaded asset with GitHub CLI:

```sh
gh release verify-asset <tag> <filename> --repo PRO-2684/static-rsync
```
