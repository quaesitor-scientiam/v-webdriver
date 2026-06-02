# Mobile Testing Guide

How to set up and run [`vebidor.mobile`](mobile/) against an iOS Simulator
and an Android Emulator. This is the native-mobile analog of
[TESTING.md](TESTING.md) (which covers the web side).

`vebidor.mobile` talks directly to the on-device automation servers —
**WebDriverAgent** (WDA) on iOS and the **UiAutomator2 server** on Android —
so the setup is mostly about getting those servers built/installed and
running. Once they answer on their local port, the V code just drives them.

> **Module path.** Like the rest of the project, examples import
> `vebidor.mobile`, so the checkout must be on V's module path. From the
> repo root:
> ```bash
> mkdir -p ~/.vmodules && ln -s "$(pwd)" ~/.vmodules/vebidor
> ```

---

## iOS (Simulator, macOS)

### Prerequisites

- macOS with **Xcode** + command-line tools.
- An iOS Simulator runtime installed (Xcode → Settings → Platforms).
- A local clone of [WebDriverAgent](https://github.com/appium/WebDriverAgent)
  (standalone, or the copy under `~/.appium/.../appium-webdriveragent`).

### 1. Pick / create a Simulator

```bash
xcrun simctl list devices available          # find an iPhone + its UDID
xcrun simctl boot "iPhone 17 Pro"            # boot by name (or by UDID)
open -a Simulator
```

If the device you want doesn't exist yet, create it:

```bash
xcrun simctl list runtimes                   # find an iOS runtime id
xcrun simctl create "iPhone 16" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-16 \
  com.apple.CoreSimulator.SimRuntime.iOS-26-5
```

### 2. Build WebDriverAgent for testing

From the WebDriverAgent checkout (note: **no space** after the comma in
`-destination`, and use a device that actually exists):

```bash
xcodebuild -project WebDriverAgent.xcodeproj \
  -scheme WebDriverAgentRunner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build-for-testing
```

This writes a `WebDriverAgentRunner_*.xctestrun` file into DerivedData.
Find it:

```bash
find ~/Library/Developer/Xcode/DerivedData \
  -name "WebDriverAgentRunner_iphonesimulator*.xctestrun"
```

### 3a. Let Vebidor auto-launch WDA (recommended)

`launch_ios(.simulator)` boots the Sim and spawns WDA for you:

```bash
export IOS_SIM_UDID='<udid from simctl list>'
export WDA_XCTESTRUN='/Users/.../WebDriverAgentRunner_iphonesimulator26.5-arm64.xctestrun'
v run examples/mobile/example_mob_ios_sim.v
```

### 3b. Or run WDA yourself and attach

```bash
xcodebuild test-without-building \
  -xctestrun '<path>/WebDriverAgentRunner_*.xctestrun' \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

curl http://localhost:8100/status            # should report "ready": true
```

Then drive it with `launch_ios(.attach)` (the default `wda_url` is
`http://localhost:8100`) — see `examples/mobile/example_mob_ios.v`.

---

## Android (Emulator, macOS/Linux/Windows)

### Prerequisites

- **Android platform-tools** (`adb`) on `PATH`.
  ```bash
  brew install --cask android-platform-tools     # macOS
  adb version
  ```
- A **JDK** (for `sdkmanager` / `avdmanager`). Temurin 17 is a safe choice:
  ```bash
  brew install --cask temurin@17
  export JAVA_HOME=$(/usr/libexec/java_home -v 17)
  ```
- The Android command-line tools + an emulator system image. With the
  Homebrew cask the SDK root is `/opt/homebrew/share/android-commandlinetools`:
  ```bash
  export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
  export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
  ```

### 1. Create & boot an emulator

```bash
yes | sdkmanager --licenses
sdkmanager "system-images;android-34;google_apis_playstore;arm64-v8a" "emulator"
avdmanager create avd -n pixel34 \
  -k "system-images;android-34;google_apis_playstore;arm64-v8a" -d pixel_7

emulator -avd pixel34 &
adb wait-for-device shell 'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done'
adb devices                                   # emulator-5554  device
```

> On Apple Silicon use an **arm64-v8a** system image. APKs that ship only
> x86/x86_64 native libs fail to install with `INSTALL_FAILED_NO_MATCHING_ABIS`.

### 2. Get the UiAutomator2 server APKs

Two APKs from the
[appium-uiautomator2-server releases](https://github.com/appium/appium-uiautomator2-server/releases):

```bash
mkdir -p ~/apks && cd ~/apks
V=v10.2.1
curl -L -o uia2-server.apk \
  https://github.com/appium/appium-uiautomator2-server/releases/download/$V/appium-uiautomator2-server-$V.apk
curl -L -o uia2-server-test.apk \
  https://github.com/appium/appium-uiautomator2-server/releases/download/$V/appium-uiautomator2-server-debug-androidTest.apk
file *.apk                                     # confirm: Android package (APK), not HTML
```

> Always `file`-check a downloaded APK before installing. A 404 saves an
> HTML error page, which fails install with `INSTALL_PARSE_FAILED_NOT_APK`.

### 3. Run

`launch_android(.spawn)` installs the APKs, starts the instrumentation,
forwards `tcp:6790`, polls until the server answers, and tears it all down
on `close()`:

```bash
export ANDROID_UDID='emulator-5554'
export UIA2_SERVER_APK="$HOME/apks/uia2-server.apk"
export UIA2_SERVER_TEST_APK="$HOME/apks/uia2-server-test.apk"

v run examples/mobile/example_mob_android.v
```

---

## Examples

| Example | Drives | Platform |
|---|---|---|
| `example_mob_ios.v` | Settings smoke test (attach) | iOS |
| `example_mob_ios_sim.v` | Settings smoke test (auto-launch) | iOS |
| `example_mob_android.v` | Settings smoke test | Android |
| `example_mob_cross.v` | Cross-platform selectors (`PLATFORM=ios\|android`) | both |
| `example_mob_assertions.v` | `expect()` + gestures | iOS |
| `example_mob_appstate.v` | App lifecycle + orientation | Android |
| `example_mob_devicestate.v` | Lock / geolocation / network | Android |

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `unknown type vebidor.mobile.X` on `v run` | Checkout not on the module path — symlink it into `~/.vmodules` (see top). |
| `xcodebuild: error: unreadable input ' name=…'` | Space after the comma in `-destination`. Remove it. |
| `Invalid device or device pair` | The named Simulator doesn't exist — `simctl list devices available` and use the exact name/UDID. |
| `xctestrun file not found` | Wrong path/version/arch — find the real one in DerivedData; the arch matches your host (arm64 on Apple Silicon). |
| `Invalid locator requested: -ios predicate string` | You're hitting WDA directly — use `predicate string`, not Appium's `-ios ` prefix. |
| `FindElementModel: mandatory field 'selector'` | UiA2 wants `strategy`/`selector`, not W3C `using`/`value`. (Handled by the library; only relevant if you're calling raw.) |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | x86-only APK on an arm64 emulator — use an arm64 image or an arch-neutral APK. |
| Rotation times out on the emulator | UiA2 hard-codes a 2 s rotation-settle wait; a busy foreground activity can exceed it. The call is correct — retry or treat as non-fatal. |
