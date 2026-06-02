# Vebidor Mobile vs Appium — Comparison & Status

## Overview

This document compares [`vebidor.mobile`](mobile/) with [Appium](https://appium.io/),
the de-facto standard for cross-platform native mobile automation. Where the
[Playwright](COMPARISON_WITH_PLAYWRIGHT.md) and [Selenium](COMPARISON_WITH_SELENIUM.md)
comparisons cover the *web* side, this one covers Vebidor's **native mobile** module.

The core idea: Appium and `vebidor.mobile` talk to the **same on-device
automation servers** — [WebDriverAgent](https://github.com/appium/WebDriverAgent)
(WDA) on iOS and the [UiAutomator2 server](https://github.com/appium/appium-uiautomator2-server)
on Android. Appium wraps them in a Node.js server that translates W3C
requests into each backend's dialect. `vebidor.mobile` **talks to those
servers directly from V**, with no Node hop in between.

```
Appium:           your test → Appium (Node) → WDA / UiA2 → device
vebidor.mobile:   your test → WDA / UiA2 → device
```

> For a consolidated four-way view (vebidor vs Selenium, Playwright & Appium), see [COMPARISON.md](COMPARISON.md).

**Status:** Mob-1 through Mob-6.1 are implemented. The entire Android path
(UiAutomator2 over adb) is **verified live on an Android Emulator**; the iOS
path (WDA over a Simulator) is verified live for sessions, selectors,
assertions, and gestures, with app-lifecycle/device-state iOS endpoints
wired but pending a Simulator validation pass.

---

## Architecture

| | Appium | vebidor.mobile |
|---|---|---|
| Client language | Any (Java/Python/JS/Ruby/…) | V |
| Middleware | Appium Node server + driver plugins | none |
| iOS backend | WebDriverAgent | WebDriverAgent (same) |
| Android backend | UiAutomator2 server | UiAutomator2 server (same) |
| Wire protocol | W3C WebDriver over HTTP | W3C / native server dialect over HTTP |
| Bridge tooling | bundled (xcodebuild, go-ios, adb) | the same tools, invoked directly |
| Process model | out-of-process (extra Node hop) | out-of-process (one fewer hop) |

`vebidor.mobile` reuses the web module's `HttpTransport`, lazy auto-waiting
`Locator`, and `poll_until_true` assertion engine — so the mobile API
*feels* like the web API, and the plumbing has a single owner. See
[MOBILE_PLAN.md](MOBILE_PLAN.md) for the full architectural rationale.

---

## Feature comparison

### Sessions & elements — implemented

| Feature | vebidor.mobile | Appium | Notes |
|---|---|---|---|
| Session create / teardown | ✅ `launch_ios` / `launch_android` | ✅ | [`launcher.v`](mobile/launcher.v) — boots Sim/Emulator, spawns the backend, polls `/status`, tears down on `close()` |
| Auto-launch the backend | ✅ `xcodebuild` / `adb am instrument` | ✅ | [`wda_bridge.v`](mobile/wda_bridge.v), [`uia2_bridge.v`](mobile/uia2_bridge.v) |
| Attach to a running backend | ✅ `.attach` mode | ✅ | both iOS and Android |
| Find element(s) | ✅ `find_element` / `find_elements` | ✅ | [`wda.v`](mobile/wda.v) — emits each backend's native find payload |
| Element actions | ✅ tap / send_keys / clear / text / attribute | ✅ | [`wda.v`](mobile/wda.v) |
| Page source (element tree) | ✅ `page_source` | ✅ | XCUITest XML / UiAutomator XML |

### Locators & selectors — implemented

| Feature | vebidor.mobile | Appium | Notes |
|---|---|---|---|
| Native strategies | ✅ accessibility id, predicate, class chain, xpath (iOS); id, class name, UiSelector, xpath (Android) | ✅ | [`wda_locators.v`](mobile/wda_locators.v), [`uia2_locators.v`](mobile/uia2_locators.v) |
| Lazy auto-waiting locator | ✅ `MobileLocator` re-resolves on use | ✅ (client-dependent) | [`locator.v`](mobile/locator.v) — staleness-immune |
| Cross-platform semantic selectors | ✅ `get_by_label/text/test_id/role` | ⚠️ partial (driver-specific) | [`selectors.v`](mobile/selectors.v) — one call, compiles per platform |

### Assertions & gestures — implemented

| Feature | vebidor.mobile | Appium | Notes |
|---|---|---|---|
| Web-first retrying assertions | ✅ `expect(loc).to_be_visible()` etc. | ❌ (use a separate lib) | [`assertions.v`](mobile/assertions.v) — `.not()` / `.with_timeout()` |
| Touch gestures | ✅ tap / swipe / long_press / drag / scroll_into_view | ✅ | [`gestures.v`](mobile/gestures.v) — W3C touch actions |

### App lifecycle & device state — implemented

| Feature | vebidor.mobile | Appium | Notes |
|---|---|---|---|
| Activate / terminate / query app | ✅ | ✅ | [`app.v`](mobile/app.v) — WDA `/wda/apps/*` (iOS), adb (Android) |
| Background app | ✅ `background_app(seconds)` | ✅ | |
| Install / remove app | ✅ (Android); iOS → simctl/go-ios | ✅ | WDA has no install endpoint |
| Orientation | ✅ `orientation` / `set_orientation` | ✅ | [`device.v`](mobile/device.v) — W3C `/orientation`, both backends |
| Lock / unlock / is_locked | ✅ | ✅ | [`device_state.v`](mobile/device_state.v) — WDA (iOS), adb keyevents (Android, non-secure) |
| Geolocation | ✅ | ✅ | simctl (iOS) / `adb emu geo fix` (Android emulator) |
| Network conditioning | ✅ (Android) | ✅ | airplane / wifi / data / emu throttle; no per-session iOS path |

---

## What Appium has that vebidor.mobile does not (yet)

| Feature | Status in vebidor.mobile |
|---|---|
| Hybrid app / WebView automation | ❌ deferred — WDA Safari & UiA2 WebView-over-CDP are their own phase |
| Client libraries in many languages | ❌ V only |
| Plugin ecosystem (images, gestures plugins, etc.) | ❌ |
| Real-device Android validation | ⚠️ emulator-validated; real device deferred |
| Secure unlock (PIN / pattern / password) | ❌ non-secure keyguard only |
| iOS network throttling | ❌ no per-session path (host Network Link Conditioner only) |
| Mature ecosystem / cloud-grid integrations | ❌ |

---

## When to use which

**Reach for Appium when** you need many client languages, hybrid/WebView
support, a plugin ecosystem, real-device farms, or cloud grids (BrowserStack,
Sauce Labs). It's the mature, batteries-included choice.

**Reach for `vebidor.mobile` when** you're in a V codebase and want native
mobile automation with the same Playwright-style ergonomics as the web
module, one fewer process in the loop, and a W3C-standards posture — without
standing up a Node server. Same on-device backends, less middleware.

---

## Verified live

- **Android Emulator** (Pixel AVD, API 34, arm64; UiAutomator2 server
  v10.2.1): session lifecycle, native + cross-platform selectors,
  assertions, gestures, app lifecycle (activate/terminate/state),
  orientation, lock/unlock/is_locked, geolocation, network toggles.
- **iOS Simulator** (iPhone 17 Pro, iOS 26.5; WDA): session lifecycle,
  selectors, assertions, gestures, screenshots.

See [MOBILE_PLAN.md](MOBILE_PLAN.md) for per-phase status and
[MOBILE_TESTING.md](MOBILE_TESTING.md) for setup.
