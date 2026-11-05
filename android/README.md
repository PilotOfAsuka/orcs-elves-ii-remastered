# Private Android test shell

The APK packages the same offline Web export and BREW 7.0.41 WASM core, with the
existing adaptive Godot UI. It requires Android 8.0/API 26 or newer, a WebGL 2
capable device and a current Android System WebView. It is a test build, not a
store release. No APK is committed or uploaded by the build tool.

The Activity serves only packaged files at the reserved HTTPS app-assets origin;
file-URL access and external page navigation are disabled. The original game,
PCM audio, interface and all runtime files are inside the APK. Internet access
is not needed to play. There are no analytics or external downloads in the game.
The implementation follows the Android documentation's local-content HTTPS
pattern and file chooser API:

- https://developer.android.com/develop/ui/views/layout/webapps/load-local-content
- https://developer.android.com/reference/android/webkit/WebChromeClient#onShowFileChooser(android.webkit.WebView,%20android.webkit.ValueCallback%3Candroid.net.Uri[]%3E,%20android.webkit.WebChromeClient.FileChooserParams)

Saves use the stable /oe2-brew-v1 filesystem inside this app's own WebView data.
They are separate from Chrome/Pages saves. Settings → Download save / Import
save transfers the existing checksummed JSON backup through Android's document
picker, without broad storage permissions. The shell suspends audio/timers in
background, requests a save-filesystem flush, respects safe display insets and
routes Android Back to the game's menu/cancel action.

## Local build

First build the normal Web core and UI, then run `python3 tools/build_apk.py`.
The optional `--version-code` and `--version-name` identify later test updates.
The tool uses Android SDK build-tools, platform 35 and JDK 17; SDK location comes
from ANDROID_SDK_ROOT or the usual macOS Android directory. No Gradle or third
party Android library is required. Original padlock sprites are decoded at UI
build time from the supported BAR, using the project's native oe2tool and
Pillow; generated assets stay out of Git.

The first build creates android/.private/test.keystore. Keep this ignored local
key for future updates with the same application ID net.pilotofasuka.oe2.test.
The key uses the conventional test password `android`, is not suitable for a
store release and is never uploaded. The signed APK goes to dist/. The tool
verifies v2/v3 signing, ZIP alignment and every packaged game asset's SHA-256,
and writes build/android/verified.json with the exact source revision and APK
hash. It rejects a Web export containing QA-only entry points.

The Android wrapper has been compiled and the package statically verified here.
A real-device/emulator Android launch and native document picker checks remain
for device testing; responsive browser checks are not equivalent to them.
