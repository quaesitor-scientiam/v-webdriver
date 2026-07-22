# Vebidor — Gaps, Known Issues, and Missing Tests

Snapshot as of 2026-07-09 (v5.1.0). Companion to
[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md). Items are grouped by kind;
each links to the code or doc it concerns.

## Feature gaps

1. **Codegen audit mode (`--update`) — built, verified live on Edge; patch/heal
   still deferred; mobile still offline-only.** Raised in external review of
   the project: the real time sink in e2e test maintenance isn't diagnosing
   failures after the fact (trace viewing), it's locators drifting stale after
   every UI refactor and having to be rewritten. `write_program`
   ([tools/codegen.v](tools/codegen.v)) now always writes a JSON sidecar
   (`out + '.codegen.json'`) alongside the emitted program, and
   `--update <sidecar.json>` (`audit_web`/`audit_android`/`audit_ios` in
   [tools/codegen.v](tools/codegen.v)) replays a persisted recording live via
   `webdriver.locator_for`/`mobile.MobileSession.locator_for` and reports
   exactly which step's `LocatorSpec` no longer resolves
   (`webdriver.locator_health`), stopping at the first break since later steps
   depend on state it would have produced. Covered by offline round-trip tests
   in `webdriver/codegen_test.v` and `mobile/codegen_capture_test.v`, plus a
   live run of `audit_web` on Edge against a local test page: an unmodified
   recording replays 4/4 steps cleanly (exit 0); a recording with one
   corrupted locator stops at exactly that step (`✗ step 3/4: click [role
   Click Us] — not found: 0 matches (need 1)`) and exits non-zero. **Android/
   iOS audit mode is still offline-tested only** — live verification needs an
   emulator/device, which wasn't available to exercise this pass.
   **Deliberately still out of scope:** an automatic patch/re-record splice
   mode — on hitting a break, drop back into live recording from that exact
   point (the session is already in the right state from the successful
   prefix) and merge a newly-recorded suffix onto the good prefix. Audit mode
   only diagnoses; it doesn't fix. That remains the natural fast-follow.

## Known functional limitations

1. **Real touch-event dispatch is pending.** `Locator.tap()` performs the tap
   gesture via Actions `pointerType:"touch"`, but actual touch *events* are not
   dispatched — WebDriver-BiDi does not expose the CDP `mobileEmulation`
   capability, so touch *detection* is emulated via preload flags
   (`maxTouchPoints`, `ontouchstart`) and tap currently synthesizes a click.
   Tracked in [COMPARISON_WITH_PLAYWRIGHT.md](COMPARISON_WITH_PLAYWRIGHT.md)
   ("real touch-event dispatch — ⏳ pending").
2. **Mobile emulation fidelity is driver-dependent.** Best on Chromium-based
   drivers (Edge/Chrome); each `emulation.*` call is gated by `supports()` and
   may be a no-op elsewhere ([emulation.v](webdriver/emulation.v)).
3. **iOS codegen is assisted-only and not device-verified.** iOS has no passive
   touch stream, so capture is a REPL (`tap x y` / `text` / `assert` / `done`).
   Its locator synthesis is offline-tested but has **never been exercised on a
   physical iOS device** ([codegen_capture.v](mobile/codegen_capture.v),
   [CODEGEN_HANDOFF.md](CODEGEN_HANDOFF.md)).
4. **Android codegen text entry is best-effort.** A tap on an `EditText` is
   detected by re-reading `page_source()` and diffing the field's `text`; fast
   or programmatic edits can be missed
   ([codegen_capture.v](mobile/codegen_capture.v)).
5. **Codegen mobile scaffold emits TODO placeholders.** Generated mobile
   programs contain `// TODO: set udid/bundle_id` / `// TODO: set
   udid/app_package` because device coordinates aren't known at emit time
   ([codegen.v:270](webdriver/codegen.v:270)).
6. **`install_app` / `remove_app` are deliberately unimplemented on iOS**
   ([app.v:14](mobile/app.v:14)).
7. **`minimize_window()` is untestable headless** — the test passes
   unconditionally in headless mode
   ([window_waits_test.v:55](webdriver/window_waits_test.v:55)).

## Issues

1. **Filename typo:** [webdriver/capabiities.v](webdriver/capabiities.v) should
   be `capabilities.v`. Cosmetic, but it hurts discoverability and any tooling
   that guesses paths by name.
2. **Stale doc:** [CODEGEN_HANDOFF.md](CODEGEN_HANDOFF.md) still lists
   "Docs (Layer 5) — not started", but the docs flip (comparison tables,
   README, CHANGELOG, v.mod bump to 5.1.0) has since landed. The handoff's
   "What's left" section should be updated or the file marked historical.
3. **No CI.** There is no `.github/workflows` (or equivalent); all tests run
   manually via [run_tests.vsh](run_tests.vsh) /
   [run_quick_tests.vsh](run_quick_tests.vsh). Even the offline suites
   (`codegen_test.v`, `mobile/selectors_test.v`,
   `mobile/codegen_capture_test.v`) — which need no browser or device — are not
   run automatically on push.
4. **Regression-watch patterns** (previously fixed real bugs; preserve in any
   rewrite, and see "Missing tests" — neither has an offline guard):
   - *Element refs in `execute_script` args* must be sent as the W3C magic-key
     map `{"element-6066-11e4-a52e-4f735466cecf": id}`, never `json.encode(el)`
     (which produces a JSON string the server won't treat as a node).
   - *Form submission* must use `requestSubmit()` with a `submit()` fallback —
     plain `form.submit()` skips the `submit` event, `onsubmit` handlers, and
     validation.

## Missing tests

### Web (`webdriver/`)

The 12 `*_test.v` files in `webdriver/` cover the **Classic** protocol surface
(elements, actions, alerts, waits, windows, CSS, shadow DOM, multi-browser) as
live integration tests, plus offline codegen tests. Nothing covers:

- **The entire modern API layer** — [launcher.v](webdriver/launcher.v),
  [locator.v](webdriver/locator.v), [selectors.v](webdriver/selectors.v),
  [assertions.v](webdriver/assertions.v),
  [wait_helpers.v](webdriver/wait_helpers.v), [fixtures.v](webdriver/fixtures.v).
  No test file references `launch_*`, `get_by_*`, `locator(...)`, or
  `expect(...)` outside of codegen emitter tests. The selector-engine string
  builders and assertion polling logic are pure enough to test offline.
- **The entire BiDi layer** — [bidi.v](webdriver/bidi.v) plus
  `bidi_context/dom/modules/network/screenshot/script/storage/trace.v`.
  Interception, routing, events, user contexts, preload scripts, and the
  Tracer were verified live/manually but have zero automated coverage.
  Message (de)serialization and route-matching are offline-testable.
- **Emulation & devices** — [emulation.v](webdriver/emulation.v),
  [devices.v](webdriver/devices.v). The 9-preset device catalog (names,
  viewport/DPR/UA values) is trivially offline-testable.
- **Plumbing** — [transport.v](webdriver/transport.v),
  [errors.v](webdriver/errors.v), [capabiities.v](webdriver/capabiities.v),
  [logging.v](webdriver/logging.v). Capability JSON serialization and W3C
  error-code mapping are pure functions with no coverage.
- **Regression guards for the two fixed bugs** in "Issues" above: an offline
  test asserting the element-ref wire shape, and one asserting the
  `requestSubmit` script content.

### Mobile (`mobile/`)

Only two test files exist, both offline:
[selectors_test.v](mobile/selectors_test.v) (escaping, role mapping) and
[codegen_capture_test.v](mobile/codegen_capture_test.v) (scaling, getevent
parsing, hit-testing, synthesis). Untested:

- [session.v](mobile/session.v), [device.v](mobile/device.v),
  [device_state.v](mobile/device_state.v), [gestures.v](mobile/gestures.v),
  [actions.v](mobile/actions.v), [app.v](mobile/app.v),
  [assertions.v](mobile/assertions.v), [locator.v](mobile/locator.v),
  [screenshot.v](mobile/screenshot.v).
- The protocol bridges — [wda.v](mobile/wda.v) /
  [wda_bridge.v](mobile/wda_bridge.v) /
  [wda_locators.v](mobile/wda_locators.v), [uia2.v](mobile/uia2.v) /
  [uia2_bridge.v](mobile/uia2_bridge.v) /
  [uia2_locators.v](mobile/uia2_locators.v). Live testing needs a
  device/emulator, but request-body construction and response parsing could be
  unit-tested offline against canned JSON.
- **iOS end-to-end**: no live verification of the iOS path at all (WDA session,
  gestures, codegen REPL) — Android has an on-emulator round-trip; iOS does not.

### Environment constraints on the existing suites

- Every `webdriver/` test except `codegen_test.v` needs a live driver +
  browser; there is no mock-transport mode, so "unit" coverage of protocol
  code is currently impossible without a browser. A fake/replay transport
  behind [transport.v](webdriver/transport.v) would unlock most of the missing
  coverage above.
- On this dev machine, `~/.vmodules/vebidor` is a **stale plain copy** (not a
  symlink) and silently shadows the working tree for any external program that
  imports `vebidor.*` — refresh it before compiling generated/example programs
  (see [CODEGEN_HANDOFF.md](CODEGEN_HANDOFF.md) "Environment gotchas").
