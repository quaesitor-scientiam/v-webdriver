# Vebidor — Project Overview

**Version 5.1.0** · MIT · [github.com/quaesitor-scientiam/vebidor](https://github.com/quaesitor-scientiam/vebidor)

Vebidor is a pure-[V](https://vlang.io/) browser and mobile automation library — a
Selenium/Playwright/Appium equivalent for the V language, with no external
runtime dependencies. It implements the W3C WebDriver protocol (Classic) and
WebDriver-BiDi, layers a Playwright-style ergonomic API on top, drives native
iOS and Android apps directly (no Appium server), and ships a codegen recorder
that turns live browser/device sessions into runnable V test source.

## What it does

- **W3C WebDriver (Classic)** — full protocol client with **100% Selenium
  feature parity**: sessions, navigation, element location/interaction, JS
  execution (sync + async), cookies, screenshots, frames, windows/tabs, alerts,
  waits/expected conditions, the complete Actions API (keyboard, mouse, wheel,
  drag-and-drop), and Shadow DOM.
- **Modern API (Playwright-style)** — one-call `launch_edge()`/`launch()` that
  auto-detects the driver and browser, picks a free port, and tears down on
  `close()`; lazy auto-waiting **Locators**; semantic selector engines
  (`get_by_role`, `get_by_text`, `get_by_label`, `get_by_placeholder`,
  `get_by_test_id`); and retrying web-first assertions
  (`expect(...).to_be_visible()` etc., invertible via `.not()`).
- **WebDriver-BiDi** — a persistent WebSocket alongside the Classic session
  (`bidi: true`): network interception/mocking (`route`, `fulfill`/`abort`),
  console/network event listeners, isolated user contexts (per-context proxy,
  geolocation, permissions, storageState), preload scripts, viewport/device
  emulation, file upload, tracing, and raw `send`/`on` access to any unwrapped
  command or event.
- **Native mobile** (`vebidor.mobile`) — drives **iOS via WebDriverAgent** and
  **Android via the UiAutomator2 server** directly over HTTP, with the same
  locator/assertion style as the web API: gestures, screenshots, device state,
  semantic selectors. No Appium in the middle.
- **Codegen / session recorder** (`tools/codegen.v`) — records a live session
  and emits a runnable V program using semantic locators.
  - **Web**: an in-page JS recorder injected over BiDi; selector ladder
    (test_id → role+name → label/placeholder → text → css), each candidate
    verified unique in-page; Alt+click records an assertion. Verified live on
    Edge (capture → emit → compile → replay).
  - **Android**: passive tap capture from `adb shell getevent`, hit-tested
    against the UiAutomator2 page source. Verified live on the emulator.
  - **iOS**: assisted REPL (`tap x y` / `text` / `assert` / `done`); synthesis
    offline-tested.

## Repository layout

| Path | Contents |
|---|---|
| [webdriver/](webdriver/) | The web module: Classic protocol client (`client.v`, `elements.v`, `actions.v`, …), BiDi (`bidi*.v`), modern API (`launcher.v`, `locator.v`, `selectors.v`, `assertions.v`), per-browser options (`edge.v`, `chrome.v`, `firefox.v`, `safari.v`), device presets (`devices.v`), codegen core (`codegen.v`, `codegen_script.v`), and `*_test.v` suites |
| [mobile/](mobile/) | The native mobile module: WDA and UiAutomator2 bridges (`wda*.v`, `uia2*.v`), session/device/gestures/locators, mobile codegen capture (`codegen_capture.v`) |
| [tools/](tools/) | CLI tools: `codegen.v` (session recorder — `v run tools/codegen.v web <url>`), `start_edgedriver.v` |
| [examples/](examples/) | Runnable examples: `example_modern_vs_classic.v`, per-phase feature examples, a latency benchmark, and `mobile/` examples |
| [docs/](docs/) | Docs site + marketing landing page (static HTML bundle) |

Root-level docs worth knowing:

- [README.md](README.md) — full feature list, installation, and quick starts per browser.
- [COMPARISON.md](COMPARISON.md) + per-tool deep dives vs [Selenium](COMPARISON_WITH_SELENIUM.md), [Playwright](COMPARISON_WITH_PLAYWRIGHT.md), and [Appium](COMPARISON_WITH_APPIUM.md).
- [TESTING.md](TESTING.md) / [TEST_ENVIRONMENT_SETUP.md](TEST_ENVIRONMENT_SETUP.md) — web test setup; [MOBILE_TESTING.md](MOBILE_TESTING.md) — iOS Simulator / Android Emulator setup.
- [CODEGEN_HANDOFF.md](CODEGEN_HANDOFF.md) — codegen architecture and verification status.
- [MOBILE_PLAN.md](MOBILE_PLAN.md) — design notes for the mobile module.
- [CHANGELOG.md](CHANGELOG.md) — release history.

## Getting started

```bash
v install vebidor
```

Then the modern API needs no manual driver management:

```v
import vebidor.webdriver

fn main() {
	mut b := webdriver.launch_edge(webdriver.LaunchOptions{ headless: true })!
	defer { b.close() }
	b.goto('https://example.com')!
	b.wd.get_by_role('link', 'More information...').click()!
}
```

Supported browsers: **Edge** and **Chrome** (EdgeDriver/ChromeDriver),
**Firefox** (GeckoDriver), **Safari** (built-in safaridriver on macOS). The
classic `new_*_driver(url, caps)` flow is also available for connecting to a
driver you start yourself.

## Testing

- Unit/integration tests live alongside the code as `*_test.v` files
  (`webdriver/`, `mobile/`) plus root-level `integration_test.v` and
  `simple_test.v`.
- `run_tests.vsh` / `run_quick_tests.vsh` drive the suites;
  `cleanup_browsers.vsh` kills stray browser/driver processes.
- Web tests need a browser + matching WebDriver (see
  [TEST_ENVIRONMENT_SETUP.md](TEST_ENVIRONMENT_SETUP.md)); mobile tests need a
  running WDA or UiAutomator2 server (see [MOBILE_TESTING.md](MOBILE_TESTING.md)).

## Status

Production ready. Web codegen is verified live on Edge; Android codegen capture
is verified live on the emulator; iOS codegen synthesis is offline-tested but
not yet exercised on a physical device.
