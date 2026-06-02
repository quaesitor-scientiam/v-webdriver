# Vebidor vs Selenium, Playwright & Appium — Four-Way Comparison

A consolidated, at-a-glance view of how **vebidor** compares with the three
tools it overlaps with. For the full feature-by-feature tables, see the
per-tool docs:

- [COMPARISON_WITH_SELENIUM.md](COMPARISON_WITH_SELENIUM.md) — vs a peer WebDriver-Classic client
- [COMPARISON_WITH_PLAYWRIGHT.md](COMPARISON_WITH_PLAYWRIGHT.md) — vs the newer-generation web tool
- [COMPARISON_WITH_APPIUM.md](COMPARISON_WITH_APPIUM.md) — native mobile, vs the de-facto standard

---

## One-line positioning

> **Vebidor is the only browser + mobile automation library native to the V
> language.** It speaks W3C standards end-to-end — WebDriver Classic,
> WebDriver-BiDi, and the same on-device servers Appium uses — with no Node
> runtime, no bundled browser, and no vendor-proprietary protocol.

---

## At a glance

| | **Vebidor** | Selenium | Playwright | Appium |
|---|---|---|---|---|
| **Domain** | Web **+ native mobile** | Web | Web | Native mobile |
| **Language home** | **V (native)** | Java/JS/Py/C#/Ruby | JS/Py/Java/.NET | JS/Py/Java/.NET/Ruby |
| **V binding** | ✅ | ❌ | ❌ | ❌ |
| **Transport** | W3C Classic + W3C BiDi + on-device servers | W3C Classic (+partial BiDi) | CDP (+ WebKit/FF shims) | WDA / UiAutomator2 via Node |
| **Standards-based** | ✅ end-to-end | ✅ | ⚠️ Chromium-centric | ✅ servers, ⚠️ Node middleware |
| **Runtime deps** | **native binary** | driver + lang runtime | **Node + bundled browser** | **Node server** |
| **Auto-waiting locators** | ✅ | ❌ (manual waits) | ✅ | ✅ |
| **Web-first assertions** | ✅ `expect()` | ❌ | ✅ | ⚠️ via client |
| **`get_by_*` selectors** | ✅ | ❌ | ✅ | ⚠️ varies |
| **Network interception** | ✅ (BiDi) | ⚠️ partial (BiDi) | ✅ (CDP) | ⚠️ proxy-based |
| **Cross-browser incl. Safari** | ✅ (W3C) | ✅ | ⚠️ bundled engines | n/a |
| **Native iOS/Android** | ✅ no Node hop | ❌ | ❌ | ✅ |
| **Hybrid-app webviews** | ❌ not yet | n/a | n/a | ✅ mature |
| **Trace viewer / video / codegen** | ⚠️ JSON tracer | ⚠️ basic | ✅ full | ⚠️ basic |
| **Ecosystem / cloud grids** | early | ✅ huge | ✅ growing | ✅ huge |

Legend: ✅ first-class · ⚠️ partial / via add-on · ❌ not available

---

## How to read it, per tool

### vs Selenium — *matches, then exceeds*
Vebidor has **100% of Selenium's WebDriver-Classic feature set**, then adds the
ergonomics Selenium lacks (auto-waiting locators, `get_by_*`, web-first
assertions) and BiDi coverage that meets-or-exceeds Selenium's. For a V
developer who'd otherwise drive a Selenium server, vebidor is strictly more
capable.

### vs Playwright — *same DX, standards transport*
Vebidor delivers Playwright's developer experience (lazy locators, semantic
selectors, retrying assertions, one-call `launch()`, route/fulfill mocking) on
a **W3C-standards transport** rather than Chromium-only CDP — so it reaches any
conformant driver, Safari included. Playwright still wins on polished tooling:
binary trace viewer, video capture, codegen. Those are conveniences, not
capability gaps.

### vs Appium — *same backends, no Node hop*
`vebidor.mobile` talks to the **exact same on-device servers** Appium uses
(WebDriverAgent on iOS, UiAutomator2 server on Android) — but directly from V
over their HTTP sockets, with no Node middleware in the path. Lower latency,
one fewer moving part. Appium still wins on hybrid-app webview driving and its
enormous plugin/cloud ecosystem.

---

## Where vebidor is genuinely unique

1. **Only real option in V** — no competitor ships a V binding.
2. **One library, four surfaces** — Classic WebDriver, WebDriver-BiDi, *and*
   native iOS/Android, all sharing one transport, locator, and assertion
   engine.
3. **Standards all the way down** — W3C WebDriver + W3C BiDi + the public
   on-device servers. No CDP lock-in, no proprietary wire.
4. **Dependency-light** — compiles to a native binary; no Node runtime, no
   bundled Chromium download.

## Where the others still win

- **Playwright** — binary trace viewer, video capture, codegen recorder.
- **Appium** — hybrid-app webview contexts, mature cloud-grid + plugin
  ecosystem, years of edge-case hardening.
- **Selenium** — 15 years of community, Selenium Grid, clients in every
  language.

---

## Honest framing

Vebidor isn't trying to out-feature the mature tools on their polish. The pitch
is narrower and sharper: **if you write V, it's the only game in town — and
it's built on W3C standards rather than a vendor's protocol.** Everything it
does, it does through a transport that any conformant driver or on-device
server understands.
