# Vebidor - W3C WebDriver Protocol Implementation

A V language implementation of the W3C WebDriver protocol for browser automation.

**Version 5.0.0** | **Playwright-style API + WebDriver-BiDi + native iOS/Android** | **100% Selenium parity** | **Production Ready**

## ⚡ Modern API (Playwright-style)

Beyond the raw W3C WebDriver methods, Vebidor ships a higher-level ergonomic
layer: one-call browser **launch**, lazy auto-waiting **Locators**, semantic
**selector engines**, and retrying **web-first assertions**.

```v
import vebidor.webdriver

fn main() {
	// Auto-detects the driver + browser, picks a free port, and tears
	// everything down on close(). No manual "start chromedriver" step.
	mut b := webdriver.launch_edge(webdriver.LaunchOptions{ headless: true })!
	defer { b.close() }

	b.goto('https://example.com')!

	// Locators are lazy and auto-wait for the element to be actionable.
	b.wd.get_by_role('link', 'More information...').click()!

	// Web-first assertions poll until the condition holds (or time out).
	webdriver.expect(b.wd.get_by_role('heading', '')).to_be_visible()!
}
```

**Selector engines:** `get_by_role`, `get_by_text`, `get_by_label`,
`get_by_placeholder`, `get_by_test_id`, plus `wd.locator('css=...' | 'xpath=...')`
with chaining (`row.locator('td')`) and `nth(i)` / `first()`.

**Auto-waiting actions:** `click`, `fill`, `type_text`, `clear` wait for the
element to be attached, visible, enabled, and scrolled into view.

**Assertions:** `to_be_visible` / `to_be_hidden` / `to_be_enabled` /
`to_be_disabled`, `to_have_text` / `to_contain_text` / `to_have_value` /
`to_have_attribute` / `to_have_count`, each invertible via `.not()` and tunable
via `.with_timeout(ms)`.

### WebDriver-BiDi (bidirectional)

Launch with `bidi: true` to get a persistent WebSocket alongside the Classic
session, unlocking event-driven features Classic cannot offer — network
interception/mocking, console/network listeners, isolated contexts, and more.

```v
mut b := webdriver.launch_edge(webdriver.LaunchOptions{ headless: true, bidi: true })!
defer { b.close() }
mut bidi := b.bidi()!
defer { bidi.close() }
ctx := bidi.first_context()!

// Mock a response (Playwright route.fulfill style).
bidi.route(fn (req webdriver.InterceptedRequest) {
	if req.url.contains('/api') {
		req.fulfill(200, 'application/json', '{"mocked":true}') or {}
	} else {
		req.continue_request() or {}
	}
})!

bidi.add_preload_script('() => { window.__patched = true }')!   // runs before page scripts
bidi.navigate(ctx, 'https://example.com')!
bidi.on_log(fn (e webdriver.LogEntry) { println('${e.level}: ${e.text}') })!
```

**BiDi capabilities:** request/response interception + mocking (`route`,
`route_response`, `fulfill`/`abort`/`continue`), HTTP auth (`on_auth`),
console/network events (`on_log`/`on_request`/`on_response`), `wait_for_event`,
isolated user contexts (with per-context **proxy**, **geolocation**,
**permissions**, and **storageState** session reuse), preload scripts +
`call_function`, viewport emulation, partition-aware cookies
(`get_cookies(user_context: uc)`) + `on_cookie_changed`, screenshots/PDF, file
upload (`set_files`), and a `Tracer`. Capability probing via `status()` /
`supports()`. Any unwrapped command/event is reachable via `send`/`on` (or
`on_sync` for inline observers).

**Mobile emulation** (Playwright-style): device presets
(`emulate_device(ctx, 'iPhone 14')`, 9 built-in), `emulate()` for viewport/DPR/UA/
touch flags, `Locator.tap()`, `set_request_user_agent` (server-side UA), and
`set_locale`/`set_timezone`/`set_screen_orientation`. (Real touch-*event* dispatch
needs a CDP/`mobileEmulation` capability BiDi doesn't expose; touch *detection* is
emulated.)

See [COMPARISON_WITH_PLAYWRIGHT.md](COMPARISON_WITH_PLAYWRIGHT.md) for the full
Playwright/Selenium feature mapping.

## 🚀 Features

### ✅ Fully Implemented (100% Coverage) 🎉

**Core Features:**
- **Modern API** - One-call `launch()`, lazy auto-waiting Locators, selector engines, and web-first assertions (see [⚡ Modern API](#-modern-api-playwright-style))
- **WebDriver-BiDi** - Bidirectional WebSocket transport: network interception/mocking, console/network events, isolated contexts, preload scripts, file upload, tracing
- **Session Management** - Create, manage, and quit browser sessions
- **Navigation** - Navigate, back, forward, refresh
- **Element Location** - Find elements by CSS selector, XPath, ID, class name, tag name, link text
- **Element Interaction** - Click, send keys, clear, submit forms ✅ 100% Complete
- **JavaScript Execution** - Execute synchronous and asynchronous scripts ✅ 100% Complete
- **Cookies** - Get, add, delete, clear all cookies
- **Screenshots** - Capture page and element screenshots (base64)
- **Frame Switching** - Switch between frames, iframes, and parent frame
- **Actions API** - Complete keyboard, mouse, wheel, drag-and-drop ✅ 100% Complete

**Phase 1 & 5 - Element Properties** ✨ ✅ 100% Complete:
- Get element text, attributes, and DOM properties
- Check visibility (`is_displayed`), enabled state (`is_enabled`), selection state (`is_selected`)
- Get tag names, clear input fields
- Get computed CSS property values (`get_css_value`) - colors, fonts, dimensions, spacing

**Phase 2 - Alert Handling** ✨:
- Accept and dismiss alert/confirm/prompt dialogs
- Read alert text messages
- Send text input to prompt dialogs

**Phase 3 - Page Information** ✨:
- Get page title and current URL
- Get complete HTML page source
- Navigation verification

**Phase 4 - Window & Waits** ✨:
- Switch between windows and tabs
- Create new windows/tabs
- Maximize, minimize, and fullscreen windows
- Implicit waits for auto-waiting elements
- Configurable page load and script timeouts

**Phase 6 - Expected Conditions** ✨:
- Wait for elements to be clickable, visible, or present
- Wait for specific text in elements
- Get current timeout configuration
- Robust wait patterns with 500ms polling

**Phase 7 - Advanced Actions** ✨:
- Context click (right-click) on elements
- Click and hold + release for drag operations
- Drag and drop to element or by pixel offset
- Get element position and size (rect)
- Submit forms easily

**Phase 8 - Async JS & Shadow DOM** ✨ ✅ 100% Complete:
- Execute asynchronous JavaScript with callbacks
- Support for setTimeout, Promises, async/await patterns
- Access Shadow DOM roots
- Find elements within Shadow DOM
- Test modern web components (Lit, Stencil, etc.)

**Edge-Specific:**
- Network condition simulation
- Device emulation
- Browser version detection

## 📦 Installation

### Prerequisites
1. [V compiler](https://vlang.io/) installed
2. A supported browser (Edge, Chrome, Firefox, or Safari)
3. Matching WebDriver:
   - **Edge**: [EdgeDriver](https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/) (port 9515)
   - **Chrome**: [ChromeDriver](https://chromedriver.chromium.org/) (port 9515)
   - **Firefox**: [GeckoDriver](https://github.com/mozilla/geckodriver/releases) (port 4444)
   - **Safari**: Built-in SafariDriver on macOS (port 4445)

### Quick Setup

> **Tip:** With the [Modern API](#-modern-api-playwright-style) `launch()`, you
> can skip the manual driver-start step below — Vebidor finds the driver on
> `PATH` (or via `EDGEDRIVER`/`CHROMEDRIVER`/`GECKODRIVER`), starts it on a free
> port, and stops it for you. The steps below are for the classic
> `new_*_driver(url, caps)` flow that connects to a driver you started yourself.

```bash
# Clone the repository
git clone https://github.com/quaesitor-scientiam/v-webdriver.git
cd v-webdriver

# Register the checkout on V's module path so `import vebidor.webdriver`
# resolves. Without this step, `v run examples/*.v` will fail with
# misleading "unknown type vebidor.webdriver.XYZ" errors because V can't
# locate the module by name.
mkdir -p ~/.vmodules
ln -s "$(pwd)" ~/.vmodules/vebidor
# (Alternatively: `v install` from this directory.)

# Start your browser's WebDriver
# Edge/Chrome:
.\msedgedriver.exe --port=9515  # or chromedriver.exe

# Firefox:
.\geckodriver.exe --port=4444

# Safari (macOS):
safaridriver --enable
safaridriver -p 4445
```

**Need help?** See [TEST_ENVIRONMENT_SETUP.md](TEST_ENVIRONMENT_SETUP.md) for detailed setup instructions.

## 🎯 Quick Start

### Microsoft Edge
```v
import vebidor.webdriver

fn main() {
    caps := webdriver.Capabilities{
        browser_name: 'msedge'
        edge_options: webdriver.EdgeOptions{
            args: ['--headless=new']
            binary: r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
        }
    }

    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!
    title := wd.get_title()!
    println('Page title: ${title}')
}
```

### Google Chrome
```v
import vebidor.webdriver

fn main() {
    caps := webdriver.Capabilities{
        browser_name: 'chrome'
        chrome_options: webdriver.ChromeOptions{
            args: ['--headless=new', '--disable-gpu']
            binary: r'C:\Program Files\Google\Chrome\Application\chrome.exe'
        }
    }

    wd := webdriver.new_chrome_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!
    println('Chrome automation working!')
}
```

### Mozilla Firefox
```v
import vebidor.webdriver

fn main() {
    caps := webdriver.Capabilities{
        browser_name: 'firefox'
        firefox_options: webdriver.FirefoxOptions{
            args: ['-headless']
            binary: r'C:\Program Files\Mozilla Firefox\firefox.exe'
        }
    }

    wd := webdriver.new_firefox_driver('http://127.0.0.1:4444', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!
    println('Firefox automation working!')
}
```

### Safari (macOS)
```v
import vebidor.webdriver

fn main() {
    caps := webdriver.Capabilities{
        browser_name: 'safari'
        safari_options: webdriver.SafariOptions{
            automatic_inspection: false
            automatic_profiling: false
        }
    }

    wd := webdriver.new_safari_driver('http://127.0.0.1:4445', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!
    println('Safari automation working!')
}
```

## 📖 Comprehensive Examples

### Complete Automation Example (All Phases)
```v
import vebidor.webdriver

fn main() {
    caps := webdriver.Capabilities{
        browser_name: 'msedge'
        edge_options: webdriver.EdgeOptions{
            args: ['--headless=new']
        }
    }

    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    // Set timeouts (Phase 4)
    wd.set_implicit_wait(10000)!
    wd.set_page_load_timeout(30000)!

    // Navigate and get page info (Phase 3)
    wd.get('https://example.com')!
    title := wd.get_title()!
    url := wd.get_current_url()!
    println('Page: ${title} at ${url}')

    // Element properties (Phase 1)
    heading := wd.find_element('css selector', 'h1')!
    text := wd.get_text(heading)!
    tag := wd.get_tag_name(heading)!
    visible := wd.is_displayed(heading)!
    println('Found <${tag}>: "${text}" (visible: ${visible})')

    // Handle alerts (Phase 2)
    wd.execute_script('alert("Test")', [])!
    alert_text := wd.get_alert_text()!
    println('Alert says: ${alert_text}')
    wd.accept_alert()!

    // Multi-window (Phase 4)
    new_tab := wd.new_window('tab')!
    wd.switch_to_window(new_tab.handle)!
    wd.get('https://www.iana.org')!
    wd.maximize_window()!
}
```

### Form Automation
```v
import vebidor.webdriver

fn login_example() ! {
    caps := webdriver.Capabilities{
        browser_name: 'msedge'
    }

    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com/login')!

    // Find form elements
    username := wd.find_element('css selector', '#username')!
    password := wd.find_element('css selector', '#password')!
    submit := wd.find_element('css selector', 'button[type="submit"]')!

    // Fill the form
    wd.send_keys(username, 'testuser')!
    wd.send_keys(password, 'password123')!
    wd.click(submit)!
}
```

### Working with Cookies
```v
import vebidor.webdriver

fn cookie_example() ! {
    caps := webdriver.Capabilities{ browser_name: 'msedge' }
    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!

    // Add a cookie
    cookie := webdriver.Cookie{
        name: 'session_id'
        value: 'abc123'
        path: '/'
        domain: 'example.com'
    }
    wd.add_cookie(cookie)!

    // Get all cookies
    cookies := wd.get_cookies()!
    println('Cookies: ${cookies.len}')

    // Delete a cookie
    wd.delete_cookie('session_id')!
}
```

### Using Actions API
```v
import vebidor.webdriver

fn actions_example() ! {
    caps := webdriver.Capabilities{ browser_name: 'msedge' }
    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!

    // Type text using actions
    wd.type_text('Hello World')!

    // Scroll down
    wd.scroll_by(0, 500)!

    // Click at coordinates
    wd.click_at(100, 200)!
}
```

### Element Properties (Phase 1)
```v
import vebidor.webdriver

fn element_properties_example() ! {
    caps := webdriver.Capabilities{ browser_name: 'msedge' }
    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!

    link := wd.find_element('css selector', 'a')!

    // Get element properties
    text := wd.get_text(link)!                    // Visible text
    href := wd.get_attribute(link, 'href')!       // HTML attribute
    tag := wd.get_tag_name(link)!                 // Tag name

    // Check element state
    visible := wd.is_displayed(link)!
    enabled := wd.is_enabled(link)!

    println('Link: ${text} -> ${href}')
    println('Visible: ${visible}, Enabled: ${enabled}')
}
```

### Alert Handling (Phase 2)
```v
import vebidor.webdriver

fn alert_handling_example() ! {
    caps := webdriver.Capabilities{ browser_name: 'msedge' }
    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!

    // Handle alert
    wd.execute_script('alert("Hello!")', [])!
    text := wd.get_alert_text()!
    println('Alert: ${text}')
    wd.accept_alert()!

    // Handle prompt
    wd.execute_script('window.name = prompt("Your name?")', [])!
    wd.send_alert_text('Claude')!
    wd.accept_alert()!
}
```

### Page Information (Phase 3)
```v
import vebidor.webdriver

fn page_info_example() ! {
    caps := webdriver.Capabilities{ browser_name: 'msedge' }
    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!

    // Get page metadata
    title := wd.get_title()!
    url := wd.get_current_url()!
    source := wd.get_page_source()!

    println('Title: ${title}')
    println('URL: ${url}')
    println('HTML length: ${source.len} bytes')

    // Verify navigation
    assert title == 'Example Domain'
    assert url == 'https://example.com/'
}
```

### Multi-Window Management (Phase 4)
```v
import vebidor.webdriver

fn multi_window_example() ! {
    caps := webdriver.Capabilities{ browser_name: 'msedge' }
    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    wd.get('https://example.com')!

    // Get current window
    main_window := wd.get_window_handle()!

    // Create new tab
    new_tab := wd.new_window('tab')!
    wd.switch_to_window(new_tab.handle)!

    // Navigate in new tab
    wd.get('https://www.iana.org')!
    new_title := wd.get_title()!

    // Switch back to main window
    wd.switch_to_window(main_window)!

    // Window state management
    wd.maximize_window()!
    wd.fullscreen_window()!
}
```

### Timeouts and Waits (Phase 4)
```v
import vebidor.webdriver

fn timeouts_example() ! {
    caps := webdriver.Capabilities{ browser_name: 'msedge' }
    wd := webdriver.new_edge_driver('http://127.0.0.1:9515', caps)!
    defer { wd.quit() or {} }

    // Configure timeouts
    wd.set_implicit_wait(10000)!         // Auto-wait 10s for elements
    wd.set_page_load_timeout(30000)!     // 30s page load timeout
    wd.set_script_timeout(15000)!        // 15s script timeout

    wd.get('https://example.com')!

    // Now element finding automatically waits
    element := wd.find_element('css selector', 'h1')!

    // Custom wait condition
    wd.wait_for(fn (wd webdriver.WebDriver) !bool {
        title := wd.get_title()!
        return title.len > 0
    }, 5000, 500)!
}
```

## 🧪 Testing

### Run Quick Tests (~10 seconds)
```bash
v test webdriver/quick_test.v
```

### Run Full Test Suite (~1-2 minutes)
```bash
v test webdriver/
```

### Run Integration Tests (~2-3 minutes)
```bash
v run integration_test.v
```

### Run Simple Standalone Test
```bash
v simple_test.v
.\simple_test.exe
```

## 📊 Latency Benchmark

`examples/webdriver_latency_bench.v` measures round-trip latency for common WebDriver commands (`get_title`, `get_current_url`, `execute_script`) and reports min/avg/p50/p95/p99/max in milliseconds.

**Prerequisites:** a WebDriver must already be running before launching the benchmark.

```bash
# Default (stdlib net.http)
v run examples/webdriver_latency_bench.v

# Raw TCP transport (opt-in, avoids keep-alive stall)
v -d wd_use_raw_tcp run examples/webdriver_latency_bench.v
```

**Options:**

| Flag | Default | Description |
|------|---------|-------------|
| `--browser=edge\|chrome\|firefox\|safari` | `edge` | Browser to use |
| `--driver=URL` | `http://127.0.0.1:9515` | WebDriver URL |
| `--iters=N` | `200` | Number of timed iterations |
| `--warmup=N` | `20` | Warmup iterations (not measured) |
| `--binary=PATH` | *(env var)* | Path to browser executable |
| `--headless` / `--headed` | headless | Run browser headlessly or not |

**Example output:**
```
Command: get_title
  count: 200  min: 2.007 ms  avg: 2.460 ms  p50: 2.344 ms  p95: 3.045 ms  p99: 4.023 ms  max: 4.545 ms
```

## 📱 Native Mobile (iOS + Android)

Beyond browser automation, Vebidor ships a native **mobile** module
([`vebidor.mobile`](mobile/)) that drives real apps on iOS and Android — by
talking **directly** to WebDriverAgent (iOS) and the UiAutomator2 server
(Android), the same on-device backends Appium uses, but with **no Node
middleware**.

```v
import vebidor.mobile

mut s := mobile.launch_android(mobile.AndroidOptions{
    mode: .spawn
    udid: 'emulator-5554'
    app_package: 'com.android.settings'
    app_activity: '.Settings'
    uia2_server_apk: server_apk
    uia2_server_test_apk: test_apk
})!
defer { s.close() }

// Same Playwright-style surface as the web module:
mobile.expect(s.get_by_text('Battery')).to_be_visible()!
s.get_by_label('Battery').tap()!
s.set_orientation(.landscape)!
```

One API, two backends. Cross-platform `get_by_label/text/test_id/role`
selectors, lazy auto-waiting locators, `expect()` assertions, touch
gestures, app lifecycle, and device state (orientation, lock, geolocation,
network) — all sharing the web module's transport and polling engine. The
Android path is verified live on an emulator; iOS on a Simulator.

See **[COMPARISON_WITH_APPIUM.md](COMPARISON_WITH_APPIUM.md)** for the
Appium feature mapping and **[MOBILE_TESTING.md](MOBILE_TESTING.md)** for
setup.

## 📚 Documentation

- **[COMPARISON_WITH_SELENIUM.md](COMPARISON_WITH_SELENIUM.md)** - Feature comparison with Selenium
- **[COMPARISON_WITH_PLAYWRIGHT.md](COMPARISON_WITH_PLAYWRIGHT.md)** - Comparison with Playwright & roadmap
- **[COMPARISON_WITH_APPIUM.md](COMPARISON_WITH_APPIUM.md)** - Native mobile vs Appium
- **[TESTING.md](TESTING.md)** - Testing guide (web)
- **[MOBILE_TESTING.md](MOBILE_TESTING.md)** - Mobile setup guide (iOS Simulator + Android Emulator)
- **[MOBILE_PLAN.md](MOBILE_PLAN.md)** - Mobile module architecture & phase status
- **[TEST_ENVIRONMENT_SETUP.md](TEST_ENVIRONMENT_SETUP.md)** - Test environment setup
- **[CHANGELOG.md](CHANGELOG.md)** - Change history

## 🎯 Feature Coverage

**Current**: **🎉 100% feature parity with Selenium WebDriver! 🎉**
**ALL Phases Complete!** 🎊

| Category | Status |
|----------|--------|
| Session Management | ✅ 100% |
| Navigation | ✅ 100% |
| Element Location | ✅ 100% |
| Cookies | ✅ 100% |
| Screenshots | ✅ 100% |
| Frames | ✅ 100% |
| **Element Properties** | ✅ **100%** (Phase 1, 5 & 7) |
| **Alerts** | ✅ **100%** (Phase 2) |
| **Page Information** | ✅ **100%** (Phase 3) |
| **Window Management** | ✅ **100%** (Phase 4) |
| **Timeouts & Waits** | ✅ **100%** (Phase 4 & 6) |
| **Actions API** | ✅ **100%** (Phase 7) |
| **Element Interaction** | ✅ **100%** (Phase 7) |
| **JavaScript Execution** | ✅ **100%** (Phase 8) ✨ NEW |
| **Shadow DOM** | ✅ **100%** (Phase 8) ✨ NEW |

**🏆 100% FEATURE PARITY ACHIEVED! 🏆**

See [COMPARISON_WITH_PLAYWRIGHT.md](COMPARISON_WITH_PLAYWRIGHT.md) for the full Playwright/Selenium feature mapping.

## ✨ What's New in v5.0.0

**📱 Native mobile automation** — a new [`vebidor.mobile`](mobile/) module that drives
real apps on **iOS** (via WebDriverAgent) and **Android** (via the UiAutomator2 server)
directly over their HTTP sockets — the same backends Appium uses, with no Node middleware.
Sibling to `vebidor.webdriver`; shares its `HttpTransport`, lazy auto-waiting locator, and
`poll_until_true` assertion engine.

- ✅ One-call launch — `launch_ios(.simulator)` / `launch_android(.spawn)` boot the
  Simulator/emulator, spawn the backend, port-forward, poll readiness, and tear it all
  down on `close()`
- ✅ Cross-platform selectors — `get_by_role` / `get_by_label` / `get_by_text` /
  `get_by_test_id` compile to XCUITest predicates (iOS) and UiAutomator selectors (Android)
- ✅ Auto-waiting actions + W3C-actions gestures — `tap` / `fill` / `swipe_*` /
  `long_press` / `drag_to` / `scroll_into_view`
- ✅ Web-first assertions — `mobile.expect(loc).to_be_visible()` with `.not()` / `.with_timeout()`
- ✅ App lifecycle + device state — `activate_app` / `terminate_app` / `query_app_state`,
  `lock` / `unlock`, `set_orientation`, `set_geolocation`, `set_network_condition`
- 📄 See [COMPARISON_WITH_APPIUM.md](COMPARISON_WITH_APPIUM.md) and [MOBILE_TESTING.md](MOBILE_TESTING.md)

Verified live: full Android path on an Android Emulator (Pixel AVD, API 34); iOS sessions,
selectors, assertions, and gestures on an iOS Simulator.

## ✨ What's New in v4.2.0

**📱 Playwright-style mobile-web emulation** (over WebDriver-BiDi):
- ✅ Device presets — `emulate_device(ctx, 'iPhone 14')` (9 built-in: iPhone, Pixel, Galaxy, iPad)
- ✅ `emulate()` — viewport + DPR + JS-visible UA + `isMobile`/`hasTouch`
- ✅ `Locator.tap()` (touch pointer)
- ✅ `set_request_user_agent` — server-side UA (HTTP header rewrite)
- ✅ `set_locale` / `set_timezone` / `set_screen_orientation`
- ⚠️ Real touch-*event* dispatch needs a CDP/`mobileEmulation` capability BiDi doesn't expose (touch *detection* is emulated; `tap` synthesizes a click)

(v4.1.0: per-context conveniences + capability probing; v4.0.1: partition-aware cookies + inline dispatch — see CHANGELOG.)

## ✨ What's New in v4.0.0

**🎭 Playwright-style API + WebDriver-BiDi — verified live against headless Edge**

- ✅ **Locators**: lazy, auto-waiting, chainable, staleness-immune (`get_by_role/text/label/placeholder/test_id`, `nth`/`first`)
- ✅ **Web-first assertions**: `expect(loc).to_be_visible()` etc., polling, `.not()` / `.with_timeout()`
- ✅ **`launch()`**: auto-detect driver+browser, free port, teardown — no manual driver start
- ✅ **WebDriver-BiDi transport**: persistent WebSocket coexisting with the Classic session
- ✅ **Network interception/mocking**: `route`/`route_response`, `fulfill`/`abort`/`continue`, `on_auth`
- ✅ **Events**: console/network listeners, `wait_for_event`, `on_cookie_changed`
- ✅ **Isolated user contexts**, **preload scripts**, **`call_function`**, **viewport emulation**
- ✅ **File upload** (`set_files`), **BiDi cookies**, **screenshots/PDF**, **`Tracer`**
- 🐛 Fixed: W3C screenshot endpoints now use GET (were POST)

vebidor now offers Playwright-style ergonomics **and** WebDriver-BiDi coverage that meets or exceeds Selenium's, on a native V API. See [COMPARISON_WITH_PLAYWRIGHT.md](COMPARISON_WITH_PLAYWRIGHT.md).

## ✨ What's New in v3.1.1

**🐛 Multi-Browser Bug Fixes - All 4 browsers now fully functional!**

- ✅ **v3.1.1**: Fixed compile error (`new_session()` helper), Safari W3C JSON tags, moved `new_edge_driver()` to `edge.v`, standardized parameter names
- ✅ **v3.1.0**: Added Chrome, Firefox, and Safari browser support alongside Edge
- ✅ **v3.0.1**: Added `find_edge_binary` helper for automatic Edge binary detection
- ✅ **v3.0.0**: Phase 8 Complete - 100% Feature Parity with Selenium achieved!

**Total**: **40 methods** added across all phases, raising feature parity from 55% to **100%**! 🎉

**🏆 100% FEATURE PARITY WITH SELENIUM WEBDRIVER ACHIEVED! 🏆**

See individual phase documentation for detailed examples and usage.

## 🏗️ Project Structure

```
v-webdriver/
├── webdriver/
│   ├── client.v              # Core WebDriver client + Transport seam
│   ├── elements.v            # Element finding and interaction
│   ├── locator.v             # Lazy auto-waiting Locator
│   ├── selectors.v           # get_by_* selector engines
│   ├── assertions.v          # Web-first expect() assertions
│   ├── launcher.v            # launch(): driver/browser lifecycle
│   ├── fixtures.v            # v test fixtures (with_browser, etc.)
│   ├── script.v              # JavaScript execution
│   ├── window.v              # Window management
│   ├── cookies.v             # Cookie operations (Classic)
│   ├── screenshot.v          # Screenshot capture
│   ├── actions.v             # Actions API
│   ├── frame.v               # Frame switching
│   ├── wait.v                # Wait utilities
│   ├── capabiities.v         # Capabilities configuration
│   ├── types.v               # Common types
│   ├── errors.v              # Error handling
│   ├── bidi.v                # WebDriver-BiDi transport (WebSocket)
│   ├── bidi_modules.v        # BiDi browsingContext/script/log helpers
│   ├── bidi_network.v        # BiDi network interception/mocking + auth
│   ├── bidi_context.v        # BiDi user contexts, viewport, PDF, history
│   ├── bidi_script.v         # BiDi preload scripts + call_function
│   ├── bidi_storage.v        # BiDi cookies + cookieChanged
│   ├── bidi_screenshot.v     # BiDi per-context screenshots
│   ├── bidi_dom.v            # BiDi node handles + setFiles (upload)
│   ├── bidi_trace.v          # Lightweight Tracer
│   ├── webdriver_test.v      # Unit tests
│   └── quick_test.v          # Quick smoke tests
├── examples/
│   └── webdriver_latency_bench.v  # Latency benchmark tool
├── integration_test.v        # Integration tests
└── README.md                 # This file
```

## 🌐 Multi-Browser Support

Vebidor now supports **4 major browsers**:

| Browser | Driver | Default Port | Function |
|---------|--------|--------------|----------|
| **Edge** | EdgeDriver | 9515 | `new_edge_driver()` |
| **Chrome** | ChromeDriver | 9515 | `new_chrome_driver()` |
| **Firefox** | GeckoDriver | 4444 | `new_firefox_driver()` |
| **Safari** | SafariDriver | 4445 | `new_safari_driver()` |

### Browser-Specific Options

**EdgeOptions / ChromeOptions**:
```v
edge_options: webdriver.EdgeOptions{
    args: ['--headless=new', '--disable-gpu', '--no-sandbox']
    binary: r'C:\Program Files\...\browser.exe'
    extensions: ['extension1.crx', 'extension2.crx']
}
```

**FirefoxOptions**:
```v
firefox_options: webdriver.FirefoxOptions{
    args: ['-headless', '-private']
    binary: r'C:\Program Files\Mozilla Firefox\firefox.exe'
    prefs: {
        'browser.download.folderList': json.Any(2)
        'browser.download.dir': json.Any('/tmp/downloads')
    }
    profile: '/path/to/firefox/profile'
}
```

**SafariOptions**:
```v
safari_options: webdriver.SafariOptions{
    automatic_inspection: false  // Disable Web Inspector auto-open
    automatic_profiling: false   // Disable profiling auto-start
}
```

All browsers support standard W3C capabilities like `accept_insecure_certs`, `page_load_strategy`, `timeouts`, and `proxy` settings.

## 🤝 Contributing

Contributions are welcome! Now that 100% feature parity is achieved, focus areas include:

1. **Browser Testing** - Help test Chrome, Firefox, Safari drivers on different platforms
2. **Performance Optimizations** - Connection pooling, parallel execution
3. **Advanced Features** - BiDi protocol support, enhanced logging
4. **Platform Support** - macOS, Linux testing and optimization

Vebidor has achieved 100% feature parity with Selenium's core functionality!

## 📄 License

[Your License Here]

## 🙏 Acknowledgments

- Built following the [W3C WebDriver Specification](https://www.w3.org/TR/webdriver/)
- Inspired by Selenium WebDriver
- Powered by the [V Programming Language](https://vlang.io/)

## 📞 Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing documentation
- Review test files for usage examples

---

**Status**: Production-ready for web automation (Playwright-style API + WebDriver-BiDi on top of 100% Selenium parity) and native mobile automation (iOS via WebDriverAgent + Android via UiAutomator2). 🎉

**Version**: 5.0.0 (adds `vebidor.mobile` — native iOS/Android app automation; web stack unchanged: Playwright-style Locators/assertions, `launch()`, WebDriver-BiDi, mobile emulation, 4-browser support)

**Selenium-parity phases**: ✅ Phase 1 | ✅ Phase 2 | ✅ Phase 3 | ✅ Phase 4 | ✅ Phase 5 | ✅ Phase 6 | ✅ Phase 7 | ✅ Phase 8

**Playwright-parity roadmap**: ✅ Phase 0 (transport seam) | ✅ Phase 1 (locators/assertions) | ✅ Phase 2 (launch) | ✅ Phase 3 (BiDi transport) | ✅ Phase 4 (BiDi features) | ✅ Phase 5 (tooling) | ✅ BiDi gap closure vs Selenium

**Latest Update**: 2026-06-01 - v5.0.0 native mobile automation (`vebidor.mobile`: iOS/WebDriverAgent + Android/UiAutomator2, cross-platform selectors, gestures, app lifecycle, device state)

