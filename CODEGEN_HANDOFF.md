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

## Verify on the Mac
```
# one-time: make the module path a live symlink (avoids stale-copy gotcha)
ln -s "$(pwd)" ~/.vmodules/vebidor
v test webdriver/codegen_test.v          # offline emitter + parser tests
# web round-trip needs a chromedriver/edgedriver on PATH; mobile needs the emulator
```
