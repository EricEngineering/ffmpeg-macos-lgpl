# ffmpeg-macos-lgpl

Prebuilt **static, universal2 (arm64 + x86_64), LGPL** `ffmpeg` + `ffprobe` for
macOS — with **libvpx** (VP8/VP9) and **libwebp**, and **no GPL** components
(no x264/x265).

## How to (re)build

Rebuild only when bumping a version in
[`.github/scripts/build-ffmpeg-macos.sh`](.github/scripts/build-ffmpeg-macos.sh)
(`FFMPEG_VER` / `LIBVPX_VER` / `LIBWEBP_VER`):

1. Actions → **Build LGPL ffmpeg (macOS universal2)** → **Run workflow**, entering
   a `tag` (e.g. `ffmpeg-7.1`).
2. The job builds both arches on an Apple-Silicon runner, `lipo`s them into a fat
   binary, verifies (LGPL + libvpx + libwebp + both arches), and publishes
   `ffmpeg-macos-lgpl-universal2.tar.gz` to a release under that tag.
3. Point each consumer's `FFMPEG_MACOS` URL at the new tag.

Build time is ~30–60 min (compiling ffmpeg + libvpx + libwebp × 2 arches). It runs
only when you trigger it, not per app-release.

## Consuming it

The release workflow downloads and unpacks the asset into `resources/bin/`:

```bash
curl -fL --retry 3 --retry-all-errors \
  "https://github.com/EricEngineering/ffmpeg-macos-lgpl/releases/download/ffmpeg-7.1/ffmpeg-macos-lgpl-universal2.tar.gz" \
  -o ffmpeg-macos.tar.gz
mkdir -p arcaneatlas/resources/bin
tar xf ffmpeg-macos.tar.gz -C arcaneatlas/resources/bin
chmod +x arcaneatlas/resources/bin/ffmpeg arcaneatlas/resources/bin/ffprobe
```

The URL is **pinned to a tag** for reproducibility (a rebuild can't silently change
what an app ships). Use `.../releases/latest/download/...` instead if you'd rather
always track the newest build.

The consuming app is responsible for **codesigning** the binaries (hardened runtime)
before bundling them into a notarized `.app`.

## License

The binaries are FFmpeg built under the **LGPL v2.1+** with only LGPL/BSD
components. FFmpeg, libvpx, and libwebp are the property of their respective
authors; corresponding source is the upstream releases pinned in the build script.
