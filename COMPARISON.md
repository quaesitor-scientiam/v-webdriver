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
| **Trace viewer / video** | ⚠️ JSON tracer | ⚠️ basic | ✅ full | ⚠️ basic |
| **Codegen / session recorder** | ✅ web + mobile | ❌ | ✅ | ❌ |
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
conformant driver, Safari included. Vebidor now ships a **codegen / session
recorder** too — web (over BiDi) and native mobile (over the a11y tree) — that
emits semantic `get_by_*` locators rather than raw coordinates. Playwright still
wins on polished tooling: the binary trace viewer and video capture
(conveniences, not capability gaps).

### vs Appium — *same backends, no Node hop*
`vebidor.mobile` talks to the **exact same on-device servers** Appium uses
(WebDriverAgent on iOS, UiAutomator2 server on Android) — but directly from V
over their HTTP sockets, with no Node middleware in the path. Lower latency,
one fewer moving part. Appium still wins on hybrid-app webview driving and its
enormous plugin/cloud ecosystem.

---

## vs mobile-next / mobilewright — the closest peer

[mobilewright](https://github.com/mobile-next/mobilewright) is the nearest thing
to `vebidor.mobile`: a **Playwright-style mobile test framework** with semantic
locators, auto-waiting, and `expect()` assertions. The split between them is the
*same* standards-vs-integration tradeoff that separates vebidor from Playwright
on the web.

| | **vebidor.mobile** | **mobilewright** |
|---|---|---|
| Language | V (native binary) | TypeScript (Node ≥18) |
| API style | Playwright-style | Playwright-style |
| Semantic locators | `get_by_label/role/text/test_id` | `getByLabel/Role/Placeholder/Text/Type/TestId` |
| Escape-hatch selectors | ✅ xpath / predicate / class-chain / UiSelector | ❌ by design ("No XPath. No coordinates.") |
| Auto-waiting + `expect()` | ✅ | ✅ |
| iOS backend | **WebDriverAgent** (standard) | **mobilecli** (mobile-next's own agent) |
| Android backend | **UiAutomator2 server** (standard) | **mobilecli** (same agent) |
| Web + mobile in one lib | ✅ shared `get_by_*` / `expect` | ❌ mobile-only (pairs with Playwright Test for web) |
| Cloud devices | ❌ local only | ✅ via `mobile-use.com` |
| Maturity | v5.0.0; newer / smaller | v0.0.x beta; more public traction |

**The defining difference:** mobilewright is *vertically integrated* — both
platforms go through mobile-next's own `mobilecli` agent, which lets it sidestep
WebDriverAgent code-signing on iOS real devices and ship cloud devices + an
agent/LLM story. vebidor bets on the *standard public servers* (WDA +
UiAutomator2) — swappable and widely understood, but it inherits WDA's signing
friction on iOS hardware.

**mobilewright wins on:** no iOS-signing pain, cloud devices, Playwright-Test
integration, more community traction today.
**vebidor.mobile wins on:** native V (no Node), one library spanning web +
mobile, standard swappable backends, and selector escape hatches when the
semantic helpers don't fit.

If you write TypeScript and want cloud devices or zero iOS-signing hassle,
mobilewright is the more mature pick. If you write V, want web + mobile under one
API, or prefer standards over a vendor agent, `vebidor.mobile` is the only fit —
and the only V-native option at all.

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

- **Playwright** — binary trace viewer, video capture.
- **Appium** — hybrid-app webview contexts, mature cloud-grid + plugin
  ecosystem, years of edge-case hardening.
- **Selenium** — 15 years of community, Selenium Grid, clients in every
  language.
- **mobilewright** — no iOS code-signing dance, cloud devices, Playwright-Test
  integration, more community traction.

---

## Honest framing

Vebidor isn't trying to out-feature the mature tools on their polish. The pitch
is narrower and sharper: **if you write V, it's the only game in town — and
it's built on W3C standards rather than a vendor's protocol.** Everything it
does, it does through a transport that any conformant driver or on-device
server understands.
