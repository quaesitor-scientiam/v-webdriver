# Vebidor — Gaps, Known Issues, and Missing Tests

Snapshot as of 2026-07-09 (v5.1.0). Companion to
[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md). Items are grouped by kind;
each links to the code or doc it concerns.

## Feature gaps

1. **Codegen audit + patch mode (`--update` / `--update --patch`) — both
   built, verified live on Edge and Android; iOS still offline-only.** Raised
   in external review of the project: the real time sink in e2e test maintenance
   isn't diagnosing failures after the fact (trace viewing), it's locators
   drifting stale after every UI refactor and having to be rewritten.
   `write_program` ([tools/codegen.v](tools/codegen.v)) now always writes a
   JSON sidecar (`out + '.codegen.json'`) alongside the emitted program, and
   `--update <sidecar.json>` (`audit_web`/`audit_android`/`audit_ios` in
   [tools/codegen.v](tools/codegen.v)) replays a persisted recording live via
   `webdriver.locator_for`/`mobile.MobileSession.locator_for` and reports
   exactly which step's `LocatorSpec` no longer resolves
   (`webdriver.locator_health`), stopping at the first break since later steps
   depend on state it would have produced. Covered by offline round-trip tests
   in `webdriver/codegen_test.v` and `mobile/codegen_capture_test.v`, plus live
   runs:
   - **Web (Edge):** an unmodified recording replays clean (exit 0); a
     recording with one corrupted locator stops at exactly that step (`✗ step
     3/4: click [role Click Us] — not found: 0 matches (need 1)`) and exits
     non-zero.
   - **Android (emulator):** the "locator genuinely gone" path (`✗ step 1/1:
     click [test_id NoSuchIconXYZ] — not found: 0 matches (need 1)`) and the
     "locator resolves but the live action fails" path (`resolved but failed
     to perform: ...`) both verified — see "Known functional limitations" for
     why a fully clean multi-step Android replay couldn't be demonstrated in
     this pass (a separate, pre-existing bug, not audit mode).
   - **iOS: still offline-tested only** — no macOS host was available in this
     pass to run WebDriverAgent.

   While verifying, found and fixed a real bug in `audit_web`/`audit_mobile`:
   they called `exit(1)` directly on a broken step, which skips the
   `defer { b.close() }` / `defer { s.close() }` cleanup — every broken-locator
   report (the *common* case for this feature) was leaking the live
   browser/device session. Fixed by returning an error instead, so the
   existing `defer` fires normally and `main()`'s standard error handler does
   the `exit(1)`.

   **Patch mode (`--patch`) — built and live-verified, closing the fast-follow
   named above.** On a broken step, instead of just reporting and stopping,
   `patch_web`/`patch_mobile` ([tools/codegen.v](tools/codegen.v)) drop back
   into live recording on the *same already-open* browser/session (proven
   safe to do mid-flow: `Recorder.start()`
   ([codegen_script.v:186](webdriver/codegen_script.v:186)) has no
   fresh-navigation dependency, and the mobile recorders are stateless), let
   the operator record a replacement, then splice `old_acts[..broken_idx]` +
   the newly recorded suffix into a fresh program + sidecar via
   `derive_out_path` (defaults to overwriting the paths the original
   recording used, so `--update flow.v.codegen.json --patch` naturally closes
   the loop). A broken `.goto` deliberately still just stops — a URL-level
   break is a different failure class than a stale locator, and the recorder
   never observes navigation to auto-splice one. One real, load-bearing
   constraint surfaced during design: BiDi can't be attached to a session
   after it's created, so `audit_web` now launches with `bidi: true`
   whenever `--patch` is passed (unconditionally-false, i.e. no behavior
   change, when it isn't). Live-verified end to end on both platforms: a
   corrupted sidecar's broken step is detected, patch mode starts recording
   on the live session, and the spliced program + sidecar are written
   correctly (confirmed via the actual emitted `.v` source, not just exit
   codes) — Android additionally confirmed the touch-stream capture thread
   (reused from `record_android`) starts and tears down cleanly mid-audit.
   iOS not verified live (needs a Mac, out of reach in this pass) — but reuses
   the same `run_ios_repl` helper `record_ios` already uses, now extracted for
   sharing rather than duplicated.

   **Separately discovered while wiring this up (unrelated to this feature,
   noted for awareness):** `tools/` has no `v test`-able surface — it holds
   two separate `module main` programs (`codegen.v`, `start_edgedriver.v`)
   that collide on a duplicate `fn main()` the moment any file in that
   directory is compiled together for testing. A `derive_out_path`/`has_flag`
   offline test was attempted and dropped for this reason; those two pure
   helpers are covered by the live verification above instead. Splitting
   `tools/` into per-tool subdirectories would fix this generally, but is out
   of scope here.

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
8. **`is_element_displayed`/`is_element_enabled` were broken on Android
   against UiAutomator2 v10.2.1 — discovered live, now fixed.**
   `MobileSession.is_element_displayed()`/`is_element_enabled()`
   ([wda.v:164](mobile/wda.v:164)) GET the WDA (iOS)-style shorthand
   endpoints `/session/{id}/element/{id}/displayed` /`/enabled`; live probing
   confirmed UiA2 answers both with `"unknown command"` (its own
   `UnknownCommandException`, not a plain 404, but the same effect). Since
   `MobileLocator.wait_until_actionable()` ([locator.v:65](mobile/locator.v:65))
   unconditionally requires the displayed check to pass, **every action
   needing actionability — `tap()`, `fill()`, `to_be_visible()` — failed on
   Android** regardless of whether the target element genuinely existed.
   `find_element`/`find_elements` already needed UiA2-specific request
   translation elsewhere (see [MOBILE_TESTING.md](MOBILE_TESTING.md)'s
   troubleshooting table); these two never got the same treatment, and
   Android actionability may never have been live-verified at all —
   `example_mob_android.v`'s own smoke test calls `to_be_visible()` and just
   treats the failure as an expected "selector mismatch" warning.
   **Fix:** live probing found UiA2 *does* implement the generic W3C
   `/attribute/{name}` endpoint correctly (`/attribute/displayed` and
   `/attribute/enabled` both returned the right value against a real
   element), so both functions now branch on `s.platform == .android` and
   route through `element_attribute()` instead of the shorthand endpoint on
   Android, mirroring the exact dispatch pattern `find_payload` already used
   for find. iOS/WDA path unchanged. Confirmed live end-to-end: a direct
   `is_element_displayed`/`is_element_enabled` call, a real `tap()` through
   the full actionability gate, a real `to_be_visible()`, and a full
   `audit_android` clean pass (`1/1 steps OK`) on a flow that failed on this
   exact bug earlier in the same session all now succeed.
9. **`detect_adb()` didn't resolve `adb.exe` on Windows — fixed.** The
   `$ANDROID_HOME/$ANDROID_SDK_ROOT` fallback in
   [uia2_bridge.v](mobile/uia2_bridge.v) built `platform-tools/adb` with no
   platform suffix; `os.exists()` does no extension resolution of its own, so
   this fallback silently never worked on Windows (only `command_on_path`
   finding `adb` first would). Fixed by adding a local `exe_suffix()` (mirrors
   the existing one in [webdriver/launcher.v](webdriver/launcher.v)) and
   appending it to the candidate path. Confirmed live: `mobile.launch_android`
   failed with "adb not found" before the fix and worked after, against a
   real emulator.

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
