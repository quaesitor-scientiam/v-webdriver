# Codegen / session recorder — handoff

Status as of this commit. Web codegen is built and **verified live on Edge**.
Mobile capture (Layer 3) is now built and **verified live on the Android
emulator** — 24 offline tests plus an on-device round-trip (5/5 synthesized
selectors re-resolved against the live UiAutomator2 tree). iOS uses the same
core via an assisted REPL (no passive touch stream); its synthesis is
offline-tested but not yet exercised on a physical device. Audit mode (Layer
4, `--update`) is now built and **verified live on Edge and Android**: on
Edge, a recorded flow against a local test page replays cleanly (4/4 steps)
when unmodified, and when one locator is corrupted, the walk stops at exactly
that step with the right reason (`not found: 0 matches (need 1)`) and a
non-zero exit; on Android (emulator), both the "locator genuinely gone" and
"locator resolves but the live action fails" reporting paths were verified
live — see "What's left" for why a fully clean multi-step Android replay
wasn't demonstrated (a separate, pre-existing `mobile` module bug the
verification pass surfaced, not an audit-mode issue). Patch mode (`--patch`)
is now also built and **verified live on Edge and Android**: a broken step
correctly drops into live recording on the already-open session and splices
a fresh program + sidecar (confirmed via the actual emitted `.v` source).
iOS audit/patch mode is offline-tested only — no macOS host was available
this pass.

## What's done (this commit)

- **Action model + emitters** — [`webdriver/codegen.v`](webdriver/codegen.v):
  `LocatorSpec` / `RecordedAction`, `emit_v_web` (→ `get_by_*` / `expect`),
  `emit_v_mobile` (→ `mobile.get_by_*` / `tap` / `mobile.expect`). Offline tests
  in [`webdriver/codegen_test.v`](webdriver/codegen_test.v).
- **Web capture** — [`webdriver/codegen_script.v`](webdriver/codegen_script.v):
  an in-page JS recorder injected over BiDi (preload + immediate eval). Semantic
  selector ladder (test_id → role+name → label/placeholder → text → css), each
  candidate **verified unique in-page**. Alt+click records an assertion. Reports
  actions back via `console.debug(prefix+json)` captured on `log.entryAdded`
  (same path the `Tracer` uses — zero new BiDi surface). `Recorder` collects them.
- **CLI** — [`tools/codegen.v`](tools/codegen.v):
  `v run tools/codegen.v web <url> [--out f.v] [--browser edge|chrome]`. Headed
  launch, records until you press Enter, emits the program. `android`/`ios`
  subcommands are gated with a message until mobile capture lands.

Verified: capture → emit → **compile → replay** round-trip on Edge (a recorded
button/textbox/checkbox/link/Enter flow re-ran headless with exit 0).

## What's left

### Mobile capture (Layer 3) — DONE (verified live on the Android emulator)
Built in [`mobile/codegen_capture.v`](mobile/codegen_capture.v) (+ offline tests
in [`mobile/codegen_capture_test.v`](mobile/codegen_capture_test.v)); `android`
and `ios` are wired into [`tools/codegen.v`](tools/codegen.v).
- **Android passive tap-capture (primary):** `MobileSession.start_touch_stream()`
  spawns `adb shell getevent -lt`; `GetEventParser` parses `ABS_MT_POSITION_X/Y`
  + `ABS_MT_TRACKING_ID ffffffff` / `BTN_TOUCH UP`; `scale_point` maps raw coords
  → screen px using `screen_size()` (`wm size`) and `touch_axis_max()`
  (`getevent -lp`). On finger-up: `record_tap_at` snapshots `page_source()`,
  `parse_nodes` + `hit_test_index` find the smallest containing leaf, and
  `synth_locator` builds a `LocatorSpec` via the `mobile/selectors.v` priority.
  Text entry: a tap on an `EditText` defers to `flush_pending_edit`, which
  re-reads the field's `text` and emits a `fill`.
- **iOS assisted REPL (no passive touch stream):** `tap x y` / `text <s>` /
  `assert x y` / `done`; each hit-tests the current `page_source()`, performs via
  `tap_at` / `MobileLocator.fill`, and records. Synthesis is offline-tested;
  not yet run on a physical device.
- **Verified:** `v test mobile/codegen_capture_test.v` (24 cases) + a live
  on-emulator round-trip — 5/5 synthesized selectors re-resolved against the
  running UiAutomator2 tree, and a generated program type-checks.

### Audit mode / update workflow (Layer 4) — built, offline-verified

Closes a gap external review flagged: codegen only ever generated a program
from scratch, so after a UI refactor the only option was to re-record the
whole flow and hand-diff it back in. `--update <sidecar.json>` replays a
previously recorded flow live and reports exactly which step's locator no
longer resolves, instead of that. Recording now always writes a JSON sidecar
(`out + '.codegen.json'`) alongside `--out` — the same wire shape the browser
recorder already sends over console.debug (`parse_recorded`/`parse_kind` in
`codegen_script.v`), so one parser handles both the live wire protocol and a
saved file (`webdriver.actions_to_json`/`actions_from_json` in
`webdriver/codegen.v`).

- **Live locator resolution:** `webdriver.WebDriver.locator_for(spec)` (web)
  and `mobile.MobileSession.locator_for(spec)` (mobile — promoted from the
  recorder so the recorder and audit mode share one implementation) rebuild a
  live `Locator`/`MobileLocator` from a persisted `LocatorSpec`, mirroring
  `web_locator_expr`/`mobile_locator_expr`'s match arms exactly.
- **Live execution:** `Browser.perform_action` / `MobileSession.perform_action`
  are the execution twins of `web_action_line`/`mobile_action_line` — they run
  a recorded step for real instead of emitting a string of V source for it.
- **The audit walk** (`audit_web` / `audit_android` / `audit_ios` in
  `tools/codegen.v`, sharing `audit_mobile` on the mobile side): resolves each
  step's locator first (`webdriver.locator_health`, a shared pure function) —
  0 matches or an unexpected extra match is reported broken and stops the
  walk there, since later steps depend on state the broken step would have
  produced — then performs the step live so later steps see the right state.
  Prints a per-step ✓/✗ report and a summary; exits non-zero on any break.
- **Patch mode (`--patch`) — built and live-verified**, closing the
  "audit mode only diagnoses" gap noted here previously. On a broken step,
  `patch_web`/`patch_mobile` drop back into live recording on the same
  already-open browser/session (safe mid-flow — `Recorder.start()` has no
  fresh-navigation dependency, mobile recorders are stateless) instead of
  just stopping, let the operator record a replacement, and splice
  `old_acts[..broken_idx]` + the new suffix into a fresh program + sidecar
  via `derive_out_path` (defaults to the original recording's paths, so
  `--update flow.v.codegen.json --patch` closes the loop with no extra
  flags). A broken `.goto` still always just stops (different failure class —
  a URL-level break vs a stale locator — and the recorder never observes
  navigation to auto-splice one). Required unconditionally launching
  `audit_web` with `bidi: true` whenever `--patch` is passed, since BiDi
  can't be attached to a session after creation — no behavior change when
  `--patch` is absent. iOS's REPL loop was extracted into `run_ios_repl` so
  `record_ios` and patch mode share it instead of duplicating.
- **Verified:** offline round-trip tests for the JSON sidecar and both
  `locator_for` resolvers (`webdriver/codegen_test.v`,
  `mobile/codegen_capture_test.v`), plus live runs:
  - **Edge:** a clean recording replays 4/4 steps OK (exit 0), and a recording
    with one corrupted locator (`role button "Click Us"`, which doesn't exist)
    stops at exactly that step — `✗ step 3/4: click [role Click Us] — not
    found: 0 matches (need 1)` — without running the dependent step after it,
    and exits non-zero.
  - **Android (emulator):** both failure-reporting paths verified — a
    genuinely-nonexistent `test_id` is instantly caught (`✗ step 1/1: click
    [test_id NoSuchIconXYZ] — not found: 0 matches (need 1)`), and a locator
    that resolves but whose live action fails is also caught and reported
    with the real reason. A fully clean multi-step replay wasn't demonstrated
    — see the next bullet for why.
  - **iOS: not run** — no macOS host was available this pass.
- **Patch mode verified live on both platforms** — same corrupted-locator
  sidecars as above, run with `--patch` and an immediately-supplied Enter (no
  new interaction recorded, to isolate the splice mechanics from capture):
  on Edge, the walk correctly replayed the good prefix, detected the break,
  started a BiDi recorder on the live session, and wrote back a 2-action
  program containing exactly the surviving prefix; on Android, same shape —
  the touch-stream capture thread started and tore down cleanly, and the
  spliced program/sidecar were written correctly (0 actions, since the one
  recorded action was the broken one being replaced). Confirmed by reading
  the actual emitted `.v` source in both cases, not just exit codes.
- **Found and fixed two real bugs in `mobile/` while setting up this
  verification** (both pre-existing, unrelated to audit mode itself, only
  surfaced because this was the first time the mobile module was live-tested
  on Windows):
  1. `detect_adb()`'s `$ANDROID_HOME`/`$ANDROID_SDK_ROOT` fallback
     ([uia2_bridge.v](mobile/uia2_bridge.v)) built `platform-tools/adb` with
     no `.exe` suffix, so it silently never matched on Windows. Fixed with a
     local `exe_suffix()` helper, mirroring the one already in
     [webdriver/launcher.v](webdriver/launcher.v).
  2. `MobileSession.is_element_displayed()` ([wda.v](mobile/wda.v)) hits
     `/session/{id}/element/{id}/displayed`, which this UiAutomator2 server
     version (v10.2.1) 404s on. Since `wait_until_actionable()` requires this
     check unconditionally, **every actionability-gated call — `tap()`,
     `fill()`, `to_be_visible()` — currently fails on Android** regardless of
     whether the target exists. **Not fixed in this pass** — it needs its own
     investigation into UiA2's actual supported API (see
     [GAPS.md](GAPS.md) "Known functional limitations" §8) — but it explains
     why only the two failure-reporting paths above could be demonstrated
     live, not a clean end-to-end Android replay.
  3. `audit_web`/`audit_mobile` originally called `exit(1)` directly on a
     broken step, which skips `defer { b.close() }`/`defer { s.close() }` —
     leaking the live session on every broken-locator report (the *common*
     case). Fixed by returning an error instead and letting `main()`'s
     existing handler `exit(1)` after the deferred cleanup runs.

### Docs (Layer 5) — DONE
Flipped codegen "Planned" → shipped (web + mobile) across `COMPARISON.md`,
`COMPARISON_WITH_PLAYWRIGHT.md`, `docs/preview/comparison-table.html`,
`docs/ui_kits/docs/components/DocsPage.jsx`, `README.md`, `CHANGELOG.md`, and
`v.mod` (bumped to v5.1.0) — see `e5df862`/`8c0972c` in git history.

## Environment gotchas (these will bite on the Mac too)

1. **`~/.vmodules/vebidor` is a stale plain COPY**, not a symlink, and shadows the
   working tree for any EXTERNAL program that does `import vebidor.*` (in-module
   `v test webdriver/foo_test.v` is unaffected). **Before compiling generated/example
   programs, refresh it:** mirror `webdriver/` and `mobile/` into the install and
   copy `v.mod` + `vebidor.v`. On the Mac the recommended setup is a symlink
   (`ln -s "$(pwd)" ~/.vmodules/vebidor`) — see README — which avoids the staleness
   entirely. Do that on the Mac and the refresh step is unnecessary.
2. **Never type a raw `\uXXXX` escape into an editor/tool** — it can land as an
   invisible control char. The emitter builds the W3C Enter key via
   `"'" + r'\u' + code.hex() + "'"` in `press_key_literal` for this reason.

## Layer 3 build guide (mobile capture) — step by step

New files: `mobile/codegen_capture.v` + `mobile/codegen_capture_test.v`; wire
`android`/`ios` into `tools/codegen.v`. The `mobile` module already
`import vebidor.webdriver`, so **reuse** `webdriver.RecordedAction` /
`LocatorSpec` / `SelectorKind` / `emit_v_mobile` — do not redefine them. Existing
reuse points: `page_source()` + `element_rect` ([`mobile/wda.v`](mobile/wda.v)),
`tap_at` ([`mobile/gestures.v`](mobile/gestures.v)), the selector priority in
[`mobile/selectors.v`](mobile/selectors.v).

### Android passive tap-capture (primary; verified-live platform)
1. **Screen size:** `adb -s <udid> shell wm size` → `Physical size: 1080x2400`.
2. **Touch ranges:** `adb -s <udid> shell getevent -p` → find the device exposing
   `ABS_MT_POSITION_X` / `ABS_MT_POSITION_Y`, read each axis `max` (often 0..32767,
   NOT pixels). Isolate scaling in one tested fn:
   `screen_x = round(raw_x * screenW / (maxX + 1))` (and y). If a touchscreen
   already reports pixels, max ≈ screenW and the formula degenerates correctly.
3. **Event stream:** spawn `adb -s <udid> shell getevent -lt` and parse lines.
   Track the latest `ABS_MT_POSITION_X/Y`; **finger-up** = `ABS_MT_TRACKING_ID`
   value `ffffffff` (or `BTN_TOUCH ... UP`). On finger-up with a recorded down
   position → a tap at the scaled (x,y). (getevent is the only passive source;
   there is no poll alternative for taps.)
4. **Hit-test:** `s.page_source()` returns UiAutomator XML; nodes carry
   `bounds="[x1,y1][x2,y2]"`. Collect nodes whose bounds contain (x,y); pick the
   **deepest / smallest-area** (prefer `clickable="true"`).
5. **Synthesize `LocatorSpec`** from node attrs, mirroring `mobile/selectors.v`,
   verifying uniqueness by counting matches in the same XML:
   - `content-desc` non-empty & unique → `kind: .test_id` (Android `get_by_test_id`
     == accessibility id == content-desc).
   - else `resource-id` → `kind: .xpath`, value `//*[@resource-id="X"]` (note:
     `.test_id` maps to content-desc, **not** resource-id — so resource-id must go
     via xpath).
   - else `text` non-empty & unique → `kind: .text`.
   - else `class` → reverse-map to a `MobileRole` (`android.widget.Button`→button,
     `EditText`→text_field, …) + `text` as name → `kind: .role`.
   - else positional xpath fallback.
   Append `RecordedAction{ kind: .click, target: spec }` (tap == click for emit → `.tap()`).
6. **Text entry (best-effort):** when a tap lands on `android.widget.EditText`,
   re-dump `page_source()` every ~700ms and watch that node's `text`; on change,
   emit `RecordedAction{ kind: .fill, target: spec, value: <final text> }`. Document
   as best-effort.

### iOS assisted mode (no passive touch stream → REPL)
- `page_source()` is XCUITest XML; nodes carry `type`, `name`, `label`, `value`,
  and `x/y/width/height`. Hit-test by rect containment (deepest/smallest).
- REPL reading stdin: `tap <x> <y>`, `text <s>`, `assert <x> <y>`, `done`. Each
  hit-tests, performs via existing `tap_at`/`fill`, and records. Synthesis for iOS:
  `name` (accessibility id) → `.test_id`; `label` → `.label`; `type` → `.role`.

### Scaffold sketch (`mobile/codegen_capture.v`)
```v
module mobile
import vebidor.webdriver
@[heap]
pub struct MobileRecorder {
mut:
    session &MobileSession
    actions []webdriver.RecordedAction
}
pub fn (mut s MobileSession) new_recorder() &MobileRecorder { ... }
pub fn (mut r MobileRecorder) record_tap_at(x int, y int) !  { /* hit-test + append */ }
pub fn (mut r MobileRecorder) emit() string {
    plat := if r.session.platform == .ios { 'ios' } else { 'android' }
    return webdriver.emit_v_mobile(r.actions, plat)
}
```

### Offline tests (CI-friendly, no device)
- coordinate `scale_point` math; getevent line parser on captured sample lines;
- hit-test against a sample UiAutomator XML string (deepest-node containment);
- node → `LocatorSpec` synthesis (expected kind/value) for each priority branch.

## Verify
```
# Mac one-time: live symlink so the module path tracks the working tree (no stale copy)
ln -s "$(pwd)" ~/.vmodules/vebidor
v test webdriver/codegen_test.v          # offline emitter + parser + audit-helper tests
v test mobile/codegen_capture_test.v     # offline scaling/hit-test/synthesis + locator_for tests

# Web round-trip needs an edge/chromedriver on PATH.
# Mobile: start the Android emulator, `adb devices`, then:
v run tools/codegen.v android --out flow.v   # tap around, then Enter; replay flow.v to confirm

# Audit mode: recording (above) also writes flow.v.codegen.json. Re-run against
# the same page/app to confirm it still resolves cleanly (exit 0):
v run tools/codegen.v web    --update flow.v.codegen.json
v run tools/codegen.v android --update flow.v.codegen.json
# Hand-edit one entry's sel.value in the sidecar to a name that no longer
# exists, re-run, and confirm it reports that exact step broken and exits
# non-zero — this is the scenario the feature exists for.

# Patch mode: same corrupted sidecar, add --patch. On the break it drops into
# live recording on the already-open session/browser instead of stopping;
# record a replacement, press Enter (or `done` on iOS), and it splices +
# overwrites flow.v / flow.v.codegen.json. Re-run --update (no --patch) to
# confirm the patched flow now replays clean:
v run tools/codegen.v web    --update flow.v.codegen.json --patch
v run tools/codegen.v android --update flow.v.codegen.json --patch
```
