# Codegen / session recorder — handoff

Status as of this commit. Web codegen is built and **verified live on Edge**;
mobile capture is designed but not yet built (needs an Android emulator).

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

### Mobile capture (Layer 3) — needs adb + a running Android emulator
Design (from the approved plan):
- **Android passive tap-capture (primary):** stream `adb shell getevent -lt`,
  parse `ABS_MT_POSITION_X/Y` + `BTN_TOUCH`, scale touch-device coords → screen
  using ranges from `getevent -p`. On touch-up: snapshot `page_source()` (XML a11y
  tree w/ bounds), hit-test the topmost leaf containing the point, synthesize a
  `LocatorSpec` via the `mobile/selectors.v` priority, record a tap. Text entry:
  after a tap on an `EditText`, poll the node's `text` attr → emit a `fill`.
- **Cross-platform assisted mode (iOS's only path):** operator points at a target
  in a REPL; recorder hit-tests current `page_source()`, performs via existing
  `tap`/`fill`/gestures, records. **iOS has no passive touch stream** → assisted only.
- New file: `mobile/codegen_capture.v` (+ `_test.v`); wire `android`/`ios` into
  `tools/codegen.v`. Verify on the emulator (the verified-live platform).

### Docs (Layer 5) — not started
Flip codegen "Planned" → shipped (web) across `COMPARISON.md`,
`COMPARISON_WITH_PLAYWRIGHT.md`, `docs/preview/comparison-table.html`,
`docs/ui_kits/docs/components/DocsPage.jsx`; update `README.md`, `CHANGELOG.md`,
bump `v.mod`. Keep mobile codegen labeled planned until Layer 3 is verified.

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
v test webdriver/codegen_test.v          # offline emitter + parser tests (no device)
v test mobile/codegen_capture_test.v     # offline scaling/hit-test/synthesis (once added)

# Web round-trip needs an edge/chromedriver on PATH.
# Mobile: start the Android emulator, `adb devices`, then:
v run tools/codegen.v android --out flow.v   # tap around, then Enter; replay flow.v to confirm
```
