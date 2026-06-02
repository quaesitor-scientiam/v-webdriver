# Vebidor Mobile — Implementation Plan

> Status: planning. Mob-1 (foundations) is the first commit; the rest follow.
> Live design sketch: <https://quaesitor-scientiam.github.io/vebidor/ui_kits/docs/index.html#mobile>

A native V client for WebDriverAgent (iOS) and the UiAutomator2 server (Android),
talked to directly over their existing HTTP sockets — same protocols Appium uses,
minus the Node middleware. Out-of-process, W3C-aligned, fits as a sibling module
to `vebidor.webdriver`.

---

## Architectural fit

Mobile reuses ~60% of vebidor's existing infrastructure:

| Existing piece | Mobile reuse | Adjustment |
|---|---|---|
| `Transport` interface + `HttpTransport` (`webdriver/client.v`) | WDA and UiA2 both speak HTTP JSON. Point an `HttpTransport` at `http://127.0.0.1:8100` (WDA) or `http://127.0.0.1:6790` (UiA2). | Promote to its own file so `mobile/` can import without dragging Classic-WebDriver semantics. |
| `Locator` lazy auto-wait (`webdriver/locator.v`) | Same semantics: re-resolve on use, auto-wait actionability. Public API maps 1:1. | Extract the polling loop into `wait_helpers.v` so both `Locator` and `MobileLocator` use the same primitive. |
| Selector engines (`webdriver/selectors.v`) | `get_by_label`, `get_by_text`, `get_by_role`, `get_by_test_id` all have direct mobile equivalents. | New per-platform compiler functions; same public API. |
| `expect(loc).to_be_*` assertions (`webdriver/assertions.v`) | Polling / timeout / `.not()` / `.with_timeout()` are platform-agnostic. | Tiny refactor to share the polling helper. |
| Actions API + touch pointer (`webdriver/actions.v`, M3) | `pointerType:"touch"` is the mobile default; sequence builder reusable. | Add `tap`/`swipe`/`long_press`/`pinch` builders. |
| Launcher pattern (`webdriver/launcher.v`) | `launch_ios()` / `launch_android()` mirror `launch_edge()`'s shape: detect bridge tool, spawn, port-free, health-check, teardown. | Two new bridges; same RAII struct, renamed `MobileSession`. |
| Screenshot + fixtures (`webdriver/screenshot.v`, `webdriver/fixtures.v`) | Identical pattern. | One-line port. |

Net new code is WDA client, UiA2 client, two bridge modules, mobile selector
compilers, and mobile gestures. The plumbing (HTTP transport, polling, lazy
locators, assertions, lifecycle) reuses what already exists.

---

## Module structure

```
vebidor/
├── webdriver/                  ← unchanged public API (Edge/Chrome/Firefox/Safari)
│   ├── transport.v             ← NEW: extracted Transport + Response + HttpTransport
│   ├── wait_helpers.v          ← NEW: extracted polling loop (WaitOptions, poll_until_true)
│   └── … (existing files unchanged)
│
└── mobile/                     ← NEW MODULE: import vebidor.mobile
    ├── session.v               ← MobileSession (the Browser-equivalent)
    ├── launcher.v              ← launch_ios() / launch_android()
    ├── wda.v                   ← WebDriverAgent HTTP client
    ├── uia2.v                  ← UiAutomator2-server HTTP client
    ├── bridges_ios.v           ← go-ios / xcrun simctl lifecycle
    ├── bridges_android.v       ← adb / am instrument lifecycle
    ├── locator.v               ← MobileLocator (mirrors web Locator)
    ├── locators_ios.v          ← XCUITest predicate / class-chain compilers
    ├── locators_android.v      ← UIAutomator selector compilers
    ├── selectors.v             ← cross-platform get_by_* surface
    ├── actions.v               ← tap / swipe / long_press / pinch
    ├── assertions.v            ← mobile.expect() — shares polling helper
    ├── screenshot.v            ← MobileSession.save_screenshot
    └── app.v                   ← install_app / launch_app / terminate / background
```

**Why a sibling module, not files inside `webdriver/`:**

- Different mental model (devices, apps, gestures vs. browsers, windows, frames).
- Different defaults (touch is implicit, no mouse).
- Lets `webdriver` stay a clean W3C client; mobile evolves independently.
- Public API reads correctly: `import vebidor.mobile`.

`MobileSession` is its own struct (not a subclass of `WebDriver`). They share
`Transport` and the polling helpers; the command surfaces diverge enough that
forcing polymorphism would leak. Each module owns its locator type.

---

## Adjustments to the existing `webdriver` module

All non-breaking. Purely refactors that improve reuse.

1. **Extract `Transport` + `Response` + `HttpTransport` into `webdriver/transport.v`.**
   Today they live in `client.v` alongside `WebDriver`. Move them so `mobile/` can
   pick up the transport type without depending on browser-specific code.

2. **Extract polling loop into `webdriver/wait_helpers.v`.** Today
   `Locator.wait_for`, `Locator.wait_until_actionable`, and
   `LocatorAssertions.poll` each carry their own copy of the same loop. Add:

   ```v
   pub struct WaitOptions {
   pub:
       timeout_ms  int = default_timeout_ms
       interval_ms int = default_poll_ms
       describe    string
   }

   pub fn poll_until_true(opts WaitOptions, predicate fn () !bool) !
   ```

   Refactor `LocatorAssertions.poll` to delegate. (Locator's element-returning
   loops keep their inlined form for now — a generic `poll_until_ok[T]` lands
   in Mob-2 when `MobileLocator` actually needs it.)

3. **Locatable interface.** Deferred to Mob-2 — premature without
   `MobileLocator` to validate the shape against.

4. **No breaking changes to public API.** Existing users continue to call
   `webdriver.launch_edge` etc. unchanged. Mobile is purely additive.

---

## Phased implementation

Each phase shippable and demonstrable on its own, mirroring the M1–M5
mobile-emulation roadmap pattern.

### **Mob-1 — Foundations** ✅ shipped (`12481c4`)

- Refactors above (`transport.v`, `wait_helpers.v`).
- `mobile/` skeleton: `MobileSession`, `iOSOptions`, `AndroidOptions`,
  `launch_ios()` / `launch_android()` returning `error('not yet implemented')`.
- `examples/mobile/example_mob_phase1.v` — compiles, prints expected error.
- No external dependencies yet.
- **Validation:** existing webdriver builds + the example builds and errors as
  designed.

### **Mob-2 — iOS WDA client** ✅ first cut shipped + verified live on iOS Simulator (`87d397f`)

End-to-end iOS Simulator driving on macOS. The wire client (`wda.v`),
`MobileLocator` with auto-wait (`locator.v`), XCUITest selector factories
(`wda_locators.v`), action surface (`actions.v`), screenshots
(`screenshot.v`), and the iOS Settings smoke example
(`examples/mobile/example_mob_ios.v`) are all in. The launcher's
`.attach` mode connects to an already-running WDA; auto-launch ships
in Mob-2.1 below.

### **Mob-2.1 — WDA auto-launch** ✅ shipped + verified live on iOS Simulator (`2ca4047`)

`launch_ios` now spawns WebDriverAgent itself when you ask it to. The
launch mode (`IOSLaunchMode`) selects the flow:

- `.attach` (default, backward-compatible) — connect to an already-running
  WDA at `wda_url`.
- `.simulator` — `xcrun simctl boot <udid>` (idempotent) then
  `xcodebuild test-without-building -xctestrun <path> -destination …`,
  polled until `/status` answers.
- `.device` — `go-ios install` (idempotent), `go-ios runwda`, and
  `go-ios forward 8100 8100`, polled until `/status` answers. Requires
  `go-ios` on PATH and a signed WDA `.ipa`.

`MobileSession.close()` tears down whatever the launcher spawned (one
process for sim, two for device). Errors on non-macOS hosts surface
cleanly with a "macOS host required" message before any spawn is
attempted.

The example `examples/mobile/example_mob_ios_sim.v` reads `IOS_SIM_UDID`
and `WDA_XCTESTRUN` from the env so user-specific paths stay out of
source. Verified end-to-end on macOS against the iOS Simulator — boots
the Sim, spawns xcodebuild, polls until WDA answers, drives the
Settings flow, screenshots, and cleans up the xcodebuild process on
close().

### **Mob-3 — Android UiAutomator2 client** ✅ shipped + verified live on Android Emulator

Symmetric to Mob-2 over `adb`. The HTTP wrappers, element commands,
locator scaffolding, and gesture/assertion surfaces are all backend-
agnostic, so Android picks up everything from Mob-2 / Mob-5 for free —
only Android-specific session creation, selector factories, and bridge
needed implementing.

- `mobile/uia2.v` — `new_android_session(base_url, app_package,
  app_activity)`. Builds W3C capabilities with the `appium:` vendor
  prefix UiA2 requires.
- `mobile/uia2_locators.v` — `resource_id`, `class_name`, `uia2_selector`
  (UiSelector DSL), `text`, `text_contains`. (`accessibility_id` and
  `xpath` from `wda_locators.v` are W3C-standard names and work for
  UiA2 too without modification.)
- `mobile/uia2_bridge.v` — `detect_adb` (PATH, then `$ANDROID_HOME` /
  `$ANDROID_SDK_ROOT`); `install_uia2`; `start_uia2_server` (spawns
  `adb shell am instrument -w …`); `forward_port`; `check_uia2_reachable`;
  `wait_for_uia2`.
- `MobileSession` gained `on_close_cmds []string` — Android uses it to
  run `adb forward --remove` and `adb shell am force-stop` during
  teardown. iOS still doesn't need any.
- `mobile/launcher.v` — `AndroidLaunchMode` (`.attach` / `.spawn`),
  extended `AndroidOptions`, real `launch_android`. Both emulator and
  real device use the `.spawn` path since adb handles them uniformly.
- `examples/mobile/example_mob_android.v` — drives the AOSP Settings
  app on an emulator. Reads `ANDROID_UDID`, `UIA2_SERVER_APK`,
  `UIA2_SERVER_TEST_APK` from env. Demonstrates `find_elements` +
  `mobile.expect()` on Android — same code path that worked on iOS.

Verified end-to-end on macOS against the Android Emulator (Pixel AVD,
API 34, arm64) with UiAutomator2 server v10.2.1: `adb install -r` of
both APKs, `am instrument` spawn, `adb forward tcp:6790`, poll until
the UiA2 server answers, drive the Settings flow, and tear down
(`adb forward --remove` + `am force-stop`) on `close()`.

Verified on Windows that everything compiles and the example errors
cleanly at `detect_adb` when adb isn't on PATH. Live validation
(actual `adb install` / `am instrument` / port-forward / session
on the Android Emulator) needs a macOS run with the SDK + an emulator.

The two UiA2 APKs come from the
[appium-uiautomator2-server releases](https://github.com/appium/appium-uiautomator2-server/releases).
Auto-download / vendoring is a follow-up.

### **Mob-4 — Cross-platform selectors** ✅ shipped + verified live on Android Emulator

This is where the *vebidor* feel emerges — same V code drives both platforms.

- `mobile/selectors.v` — `get_by_test_id`, `get_by_label`, `get_by_text`,
  `get_by_role`, and the generic `locator(strategy, value)` escape hatch.
  Each dispatches on `s.platform` and compiles to the right backend
  strategy, returning the same lazy auto-waiting `MobileLocator` the
  single-platform factories return.
- `MobileRole` enum (`button`, `text_field`, `static_text`, `image`,
  `checkbox`, `toggle`, `link`) with per-platform mapping tables
  (XCUIElementType ⇄ android.widget class).
- Internal dispatch on `s.platform`:
  - `get_by_test_id("submit-btn")` → `accessibility id` strategy on both
    (XCUITest `name` on iOS, `content-desc` on Android).
  - `get_by_label("Sign in")` →
    - iOS: predicate `label == 'Sign in' OR name == 'Sign in' OR value == 'Sign in'`
    - Android: xpath `//*[@content-desc='Sign in' or @text='Sign in']`
      (a true OR that UiSelector can't express).
  - `get_by_text("Sign")` (substring) →
    - iOS: predicate `label CONTAINS 'Sign' OR name CONTAINS 'Sign' OR value CONTAINS 'Sign'`
    - Android: UiSelector `textContains("Sign")`.
  - `get_by_role(.button, "OK")` →
    - iOS: class chain ``**/XCUIElementTypeButton[`label == 'OK' OR …`]``
    - Android: UiSelector `className("android.widget.Button").text("OK")`.
- `mobile/locator.v` gained `find_all()` — non-erroring multi-match, backs
  role counting and iteration.
- `examples/mobile/example_mob_cross.v` — same selector + assertion source
  drives either platform; only `open_session()` differs (chosen by the
  `PLATFORM` env var).

**Mob-3 follow-on fix:** surfacing the cross-platform finders revealed that
the Android find path was sending the W3C `using`/`value` body, which the
UiAutomator2 server rejects (`FindElementModel: mandatory field 'selector'
not present`). Appium's Node driver translates W3C → UiA2's
`strategy`/`selector` shape before forwarding; talking to the server
directly, `mobile/wda.v`'s new `find_payload` helper now emits each
backend's native shape (`using`/`value` for WDA, `strategy`/`selector` for
UiA2). Confirmed against UiA2 server v10.2.1: all three selector strategies
(`get_by_text`, `get_by_label`, `get_by_role`) resolve correctly live on
the emulator.

### **Mob-5 — Assertions + gestures** ✅ shipped + verified live on iOS Simulator (`150cb5c`)

`mobile/assertions.v` — `mobile.expect(loc)` Playwright-style polling
assertions, delegating to `webdriver.poll_until_true` from Mob-1.
Methods: `to_be_visible` / `to_be_hidden` / `to_be_enabled` /
`to_be_disabled` / `to_have_text` / `to_contain_text` /
`to_have_attribute` / `to_have_count`. `.not()` inverts; `.with_timeout(ms)`
overrides the polling window. Imports `webdriver.WaitOptions` and
`webdriver.poll_until_true` directly — no logic duplicated.

`mobile/gestures.v` — W3C-actions-based touch gestures. Three element-
relative (`long_press(ms)`, `swipe_up`/`down`/`left`/`right`, `drag_to`)
that compute target coordinates from each element's rect, and three
screen-relative (`tap_at`, `long_press_at`, `swipe`). `scroll_into_view`
uses WDA's `scrollToVisible` extension because W3C actions can't
express "scroll until X". Pure JSON-building helpers — no new structs
exposed beyond `ElementRect`.

`mobile/wda.v` gained `ElementRect` + `element_rect(el)` so gestures
can find element centers and `expect(...).to_have_count(n)` can count
matches via `find_elements`.

The example `examples/mobile/example_mob_assertions.v` reuses the
Sim-launch setup and demonstrates: `expect(label).to_be_visible()`,
`expect(label).not().to_be_visible()`, `expect(label).with_timeout(ms).to_be_visible()`,
`expect(label).to_contain_text(...)`, plus `swipe_up`, `long_press`, and
`scroll_into_view` on Settings rows. Verified end-to-end on macOS
against the iOS Simulator — every assertion path, every gesture, and
the cross-module call to `webdriver.poll_until_true` all confirmed live.

Tracer integration (mirror of `bidi_trace.v` for mobile commands)
deferred to a follow-up.

### **Mob-6 — App management + device state** ✅ first cut shipped + verified live on Android Emulator

App lifecycle and device state, split by what each backend natively
exposes. Empirical probing of the running UiAutomator2 server (v10.2.1)
showed it implements `/orientation` but returns 404 "unknown command" for
the app-lifecycle and lock endpoints — Appium's Node driver does those over
adb, and so do we.

- `mobile/device.v` — `Orientation` enum + `orientation()` /
  `set_orientation(.portrait | .landscape)`. Both backends implement the
  W3C `/session/{id}/orientation` endpoint with the same PORTRAIT/LANDSCAPE
  vocabulary, so this is a single cross-platform surface with no branching.
- `mobile/app.v` — `AppState` enum (`not_installed` / `not_running` /
  `background` / `foreground`) + `activate_app(id)`, `terminate_app(id)`,
  `query_app_state(id)`, `background_app(seconds)`, `install_app(path)`,
  `remove_app(id)`. Per-platform split:
  - iOS goes over WDA's HTTP endpoints (`/wda/apps/launch`,
    `/wda/apps/terminate`, `/wda/apps/state`, `/wda/deactivateApp`).
  - Android shells out to `adb -s <udid>` (resolve launchable component +
    `am start`; `am force-stop`; `pm list packages` + `pidof` + `dumpsys
    activity` for state). `install_app` / `remove_app` are Android-only
    (`adb install -r` / `uninstall`); on iOS they error with a pointer to
    `xcrun simctl` / go-ios, since WDA has no install endpoint.
- `MobileSession` gained `app_id` (bundle id / package, set at session
  creation) and `device_udid` (adb target, set by `launch_android`).
- `examples/mobile/example_mob_appstate.v` — drives orientation +
  full app lifecycle (state → terminate → state → activate → state) on
  the emulator.

**Verified live** on the Android Emulator: app lifecycle round-trips
cleanly (`activate` → foreground, `terminate` → not_running, re-`activate`
→ foreground); orientation get/set round-trips through the library and the
raw endpoint (PORTRAIT ⇄ LANDSCAPE). Note: the emulator's rotation-settle
race can trip UiA2's hard-coded 2s wait when the foreground activity is
busy — the call is correct, the timeout is environmental, so the example
treats a rotation timeout as non-fatal.

### **Mob-6.1 — Lock state, geolocation, network** ✅ shipped + verified live on Android Emulator

The device-state tail of Mob-6. Probing UiAutomator2-server v10.2.1
confirmed it 404s on `/lock`, `/location`, and `/network_connection`, so
every Android path is adb-driven; iOS uses WDA endpoints / `xcrun simctl`.

- `mobile/device_state.v`:
  - `lock()` / `unlock()` / `is_locked()` —
    - iOS: WDA `POST /wda/lock`, `POST /wda/unlock`, `GET /wda/locked`.
    - Android: `input keyevent 223` (SLEEP) / `keyevent 224` (WAKEUP) +
      `wm dismiss-keyguard`; `is_locked` reads `dumpsys power`
      (`mWakefulness` Asleep/Dozing) OR `dumpsys window`
      (`isKeyguardShowing=true`).
  - `set_geolocation(lat, lng, alt)` —
    - iOS: `xcrun simctl location <udid> set <lat>,<lng>` (needs the
      Simulator udid, now threaded onto iOS sessions too).
    - Android: `adb emu geo fix <lng> <lat> <alt>` (emulator console;
      note the lng,lat order).
  - `set_network_condition(NetworkCondition{...})` — Android-only:
    airplane mode (`cmd connectivity airplane-mode`), Wi-Fi / data
    (`svc wifi|data`), and throttling (`adb emu network speed|delay`).
    iOS errors with a pointer to the host Network Link Conditioner.
- `MobileSession.device_udid` is now also populated for iOS
  (launch_ios .simulator / .device) so simctl-based geolocation works.
- `examples/mobile/example_mob_devicestate.v` — lock round-trip,
  geolocation fix, and network toggles on the emulator.

**Verified live** on the Android Emulator: `is_locked` false → `lock()` →
true → `unlock()` → false; `set_geolocation` accepted; airplane mode
on/off reflected in `settings global airplane_mode_on` (1 → 0); speed/delay
throttle applied.

**Known limitations (documented, deliberate):** Android `unlock` dismisses
a *non-secure* keyguard only (no PIN/pattern/password); `set_geolocation`
on Android is emulator-only (real devices need a mock-location provider);
`set_network_condition` is Android-only (no per-session iOS throttling).
The iOS lock/geolocation paths are wired and use well-established WDA /
simctl mechanisms but await a live macOS Simulator validation pass.

### **Mob-7 — Docs, release, comparison** (~1 week)

- Promote `PageMobile` from "Preview · not shipped" to a real page.
- `MOBILE_TESTING.md` (analog of `TESTING.md`): WDA prerequisites, signing,
  Simulator vs real device, emulator setup.
- `COMPARISON_WITH_APPIUM.md` — same wire, no Node, no hybrid-webview support
  yet.
- README mobile section; CHANGELOG entry for `v5.0.0` (major: new module).
- Mobile chip in the docs sidebar (stub exists at `#mobile`).

---

## Deliberately deferred from v1

- **Hybrid app webview driving** — WDA exposes Safari via WebKit Remote
  Inspector; UiA2 exposes WebViews via CDP-over-adb. Both are their own
  protocols and worth a full phase later.
- **iOS keyboard chaining / IME quirks** — `fill` on a `UITextField` works;
  complex IME flows (autocorrect, predictive text) need per-iOS-version polish.
- **Mobile-specific waits** — `wait_for_animation_settled`, `wait_for_idle`
  (Android `Looper` synchronization) are valuable but tricky.
- **Cross-platform `expect` chip-by-chip equivalence with web** — ship the
  ~80% surface; long-tail assertions follow.
- **CI** — full GitHub Actions matrix with both iOS Simulator + Android
  Emulator is a follow-up. Initial CI keeps the existing webdriver tests.

---

## Validation strategy

The maintainer is on **macOS** with **no Android devices**.

| Phase | Validatable locally |
|---|---|
| Mob-2 (iOS) | ✅ iOS Simulator on macOS, no signing |
| Mob-3 (Android) | ✅ Android Emulator via SDK |
| Mob-4 (cross-platform) | ✅ Simulator + Emulator side by side |
| Mob-5 (assertions/gestures) | ✅ |
| Mob-6 (app management) | ✅ App lifecycle works on Simulator/Emulator |
| iOS real device | ✅ when an iPhone is connected (signing on macOS) |
| Android real device | ⚠️ deferred to contributors or future device acquisition |

Simulator + Emulator cover ~95% of automation behavior. Real-device-only
quirks (real touch latency, real network, hardware sensors) are testable when
devices appear; development can complete without them.

---

## Open questions

1. **Vendored WDA binary** — ship a known-good signed `wda.ipa` in the repo,
   or require users to build their own?
2. **Vendored UiA2 APKs** — APKs don't need per-user signing, probably ship.
3. **Bridge tool requirement** — hard-require `go-ios` for iOS real-device
   (autoinstall via `brew` on macOS), or document the install step?
4. **`v5.0.0` vs `v4.3.0`** — a new module is conceptually major; leaning
   `v5.0.0`.

---

## LOC estimate

| Area | Estimate |
|---|---|
| `mobile/wda.v` | ~400 LOC |
| `mobile/uia2.v` | ~400 LOC |
| `mobile/locators_*.v` + `selectors.v` | ~600 LOC |
| `mobile/bridges_*.v` | ~700 LOC (process lifecycle is genuine work) |
| `mobile/session.v` | ~400 LOC |
| `mobile/actions.v` | ~200 LOC (reuses Actions API) |
| `mobile/assertions.v` | ~150 LOC |
| `mobile/screenshot.v`, `app.v`, etc. | ~600 LOC across 3-4 files |
| **Total** | **~3500 LOC across ~13 files** |

About 75% more than the roadmap page's `~2000 LOC` because process lifecycle
is the real work.
