# Installing Hurl

[← Back to README](../README.md)

Hurl is a single binary built on libcurl. These suites need **version 7.x**; they were written and verified
with **7.1.0**. Older versions may not support some of the syntax used here (`[FormParams]`, `isCollection`,
`toInt`).

Release downloads: <https://github.com/Orange-OpenSource/hurl/releases>
Official install guide: <https://hurl.dev/docs/installation.html>

## Linux

### Ubuntu / Debian / WSL (recommended for this workspace)

```bash
VERSION=7.1.0
curl -LO https://github.com/Orange-OpenSource/hurl/releases/download/$VERSION/hurl_${VERSION}_amd64.deb
sudo apt update && sudo apt install ./hurl_${VERSION}_amd64.deb
```

Ubuntu users can also use the PPA, which keeps hurl updated through `apt upgrade`:

```bash
sudo apt-add-repository -y ppa:lepapareil/hurl
sudo apt install hurl
```

### Fedora / RHEL / CentOS

```bash
sudo dnf install hurl
```

### Arch / Manjaro

```bash
sudo pacman -S hurl
```

### Any Linux: prebuilt tarball (no root needed)

```bash
VERSION=7.1.0
curl -LO https://github.com/Orange-OpenSource/hurl/releases/download/$VERSION/hurl-$VERSION-x86_64-unknown-linux-gnu.tar.gz
tar -xzf hurl-$VERSION-x86_64-unknown-linux-gnu.tar.gz
mkdir -p ~/.local/bin
cp hurl-$VERSION-x86_64-unknown-linux-gnu/bin/hurl* ~/.local/bin/
# make sure ~/.local/bin is on your PATH
```

## macOS

```bash
brew install hurl
```

## Windows

Pick one:

```powershell
winget install hurl
choco install hurl
scoop install hurl
```

`run.sh` is a bash script, so on Windows run it from **WSL** or **Git Bash**, or call `hurl` directly (see
"Running hurl directly" in the README).

## Other options

```bash
# Node / npm (downloads the matching binary)
npm install -g @orangeopensource/hurl

# Rust / Cargo (builds from source; needs libcurl and libxml2 dev packages)
cargo install --locked hurl

# Docker (no local install)
docker run --rm -v "$PWD":/work -w /work ghcr.io/orange-opensource/hurl:7.1.0 \
  --test --variables-file location.env --variable now_epoch=$(date +%s) \
  --variable since_epoch=$(( $(date +%s) - 1800 )) --variable today=$(date +%F) \
  location-api.hurl
```

## Verify

```bash
hurl --version
# hurl 7.1.0 (x86_64-pc-linux-gnu) libcurl/8.x ...
```

The installer also adds `hurlfmt`, which formats `.hurl` files and checks their syntax:

```bash
hurlfmt --check location-api.hurl location-api-write.hurl
```

## Editor support

- **VS Code:** search the marketplace for "Hurl" to get syntax highlighting for `.hurl` files.
- **JetBrains IDEs:** the "Hurl" plugin provides highlighting and lets you run a file from the editor.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `hurl: command not found` | The binary isn't on your `PATH`. Check `which hurl`; for the tarball install, add `~/.local/bin` to `PATH`. |
| `error while loading shared libraries: libcurl...` / `libxml2...` | Install the runtime libraries: `sudo apt install libcurl4 libxml2`. |
| `Parsing error` on a line using `isCollection`, `toInt` or `[FormParams]` | Your hurl is too old. Upgrade to 7.x. |
| `the argument '--color' cannot be used with '--no-color'` | Don't pass color flags twice. `run.sh` sets no color flag, so you can add either one. |
| `(7) Failed to connect` | The server or `base_url` can't be reached. Check it with `curl -I <base_url>`; production may only be reachable from allowed networks. |
| `(28) Operation timed out` | Add `--connect-timeout 10 --max-time 30` and retry; the server may be under load. |
