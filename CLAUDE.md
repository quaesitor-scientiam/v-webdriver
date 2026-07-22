# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

Vebidor (v5.1.0) is a pure-V browser/mobile automation library: W3C WebDriver
(Classic) + WebDriver-BiDi with a Playwright-style API (auto-waiting Locators,
`get_by_*` selector engines, `expect()` assertions, one-call `launch()`),
a native mobile module (iOS via WebDriverAgent, Android via UiAutomator2 — no
Appium), and a codegen recorder that emits runnable V test source.

See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for the full map and
[GAPS.md](GAPS.md) for known issues, limitations, and missing-test inventory.

## Layout

- `webdriver/` — web module: Classic client, `bidi*.v` (BiDi), modern API
  (`launcher.v`, `locator.v`, `selectors.v`, `assertions.v`), per-browser
  options, `devices.v`, codegen core, and all web tests.
- `mobile/` — native mobile: `wda*.v` (iOS), `uia2*.v` (Android), session /
  gestures / locators, `codegen_capture.v`.
- `tools/codegen.v` — recorder CLI (`v run tools/codegen.v web <url>`).
- `examples/`, `docs/` (docs site + marketing bundle), root-level comparison
  and testing docs.

## Building & testing

- Offline suites (no browser/device needed): `v test webdriver/codegen_test.v`,
  `v test mobile/selectors_test.v`, `v test mobile/codegen_capture_test.v`.
- Everything else in `webdriver/` is a **live integration test** — needs a
  matching WebDriver (EdgeDriver/ChromeDriver port 9515, GeckoDriver 4444) and
  browser. Runners: `run_tests.vsh`, `run_quick_tests.vsh`; stray-process
  cleanup: `cleanup_browsers.vsh`. There is no mock transport, so protocol
  code cannot currently be unit-tested offline.
- **There is no CI** — nothing runs on push. Run the offline suites at minimum
  after any change to codegen, selectors, or mobile capture.
- Root `.exe` files are local build artifacts (gitignored) — don't commit them.

## Environment gotchas (this machine)

- `~/.vmodules/vebidor` is a **stale plain copy**, not a symlink. It silently
  shadows the working tree for any EXTERNAL program that does
  `import vebidor.*` (in-module `v test webdriver/foo_test.v` is unaffected).
  Before compiling generated/example programs, refresh it: mirror `webdriver/`
  and `mobile/` into the install and copy `v.mod` + `vebidor.v`.
- Never type a raw `\uXXXX` escape through an edit tool — it can land as an
  invisible control character. Build such strings in code (see
  `press_key_literal` in the codegen emitter).

## Correctness patterns to preserve

Both were real bugs, fixed, and have **no regression tests** (see GAPS.md):

1. **Element refs in `execute_script` args** must be the W3C magic-key map
   `{'element-6066-11e4-a52e-4f735466cecf': json.Any(el.element_id)}` — never
   `json.encode(el)`, which sends a JSON *string* the server won't treat as a
   node (symptom: "Element is not a form or inside a form").
2. **Form submission** must use `requestSubmit()` with a `submit()` fallback —
   plain `form.submit()` skips the `submit` event, `onsubmit` handlers, and
   validation. The library's `submit()` already does this; keep it in rewrites.

For mobile codegen, reuse `webdriver.RecordedAction` / `LocatorSpec` /
`SelectorKind` / `emit_v_mobile` — do not redefine them in `mobile/`.

## Known quirks & open items (details in GAPS.md)

- `webdriver/capabiities.v` — filename typo (should be `capabilities.v`);
  account for it when searching by path.
- Codegen has an audit mode: `--update <sidecar.json>` (`audit_web`/
  `audit_android`/`audit_ios` in `tools/codegen.v`) replays a previously
  recorded flow live and reports which step's locator no longer resolves,
  instead of only being able to re-record from scratch. Recording always
  writes the sidecar (`out + '.codegen.json'`) alongside `--out` now. Built
  and offline-tested; `audit_web` is also **verified live on Edge** (clean
  replay + corrupted-locator detection, both exit-code-correct).
  Android/iOS audit mode is still offline-tested only — no emulator/device
  was available to exercise it live. It only diagnoses — an automatic
  patch/re-record splice mode is a deliberately deferred fast-follow (see
  GAPS.md "Feature gaps").
- iOS codegen synthesis is offline-tested only — never run on a real device;
  Android has a verified on-emulator round-trip.
- Real touch-event dispatch is pending (BiDi lacks CDP `mobileEmulation`);
  `tap()` synthesizes a click, touch *detection* is emulated via preload flags.
- The modern API layer and the entire BiDi layer have **no automated tests**;
  Classic-protocol integration tests are the only web coverage.

## Docs to keep in sync on releases

A version bump touches: `v.mod`, `README.md`, `CHANGELOG.md`, the
`COMPARISON*.md` set, and the marketing/docs bundle under `docs/` (rebuild the
marketing bundle — see git history for the codegen pattern, e.g. commit
`e5df862`).
