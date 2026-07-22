module main

import vebidor.webdriver
import vebidor.mobile
import os

// vebidor codegen CLI — record a live session and emit a runnable vebidor
// test. Web: launches a headed browser, injects the recorder over BiDi, and
// (when you press Enter) writes the generated program. Mobile: captures taps
// on a device/emulator and synthesizes cross-platform selectors. Recording
// also writes a JSON sidecar (`out + '.codegen.json'`) next to `--out`; pass
// that sidecar back via `--update` to replay the flow live and audit which
// locators still resolve, instead of only being able to re-record from
// scratch. Add `--patch` to `--update` and a broken step drops back into
// live recording on the same session (already in the right state from the
// successful prefix) instead of just reporting the break — see patch_web /
// patch_mobile.
//
//   v run tools/codegen.v web <url>     [--out file.v] [--browser edge|chrome]
//   v run tools/codegen.v android       [--out file.v] [--udid <id>] [--uia2-url <url>]
//   v run tools/codegen.v ios           [--out file.v] [--wda-url <url>] [--bundle <id>]
//
//   v run tools/codegen.v web    --update file.v.codegen.json [--browser edge|chrome] [--patch]
//   v run tools/codegen.v android --update file.v.codegen.json [--udid <id>] [--uia2-url <url>] [--patch]
//   v run tools/codegen.v ios    --update file.v.codegen.json [--wda-url <url>] [--bundle <id>] [--patch]
//
// Android is passive: tap the device, taps are captured via `adb getevent`.
// iOS has no passive touch stream, so it's a small REPL (`tap x y` / `text …`
// / `assert x y` / `done`). Both require the backend (UiA2 / WDA) reachable.

fn usage() {
	eprintln('vebidor codegen - record a live session into a vebidor test')
	eprintln('')
	eprintln('Usage:')
	eprintln('  v run tools/codegen.v web <url>  [--out file.v] [--browser edge|chrome]')
	eprintln('  v run tools/codegen.v android    [--out file.v] [--udid <id>] [--uia2-url <url>]')
	eprintln('  v run tools/codegen.v ios        [--out file.v] [--wda-url <url>] [--bundle <id>]')
	eprintln('')
	eprintln('  v run tools/codegen.v web    --update <sidecar.json> [--browser edge|chrome]')
	eprintln('  v run tools/codegen.v android --update <sidecar.json> [--udid <id>] [--uia2-url <url>]')
	eprintln('  v run tools/codegen.v ios    --update <sidecar.json> [--wda-url <url>] [--bundle <id>]')
	eprintln('')
	eprintln('  ...--update <sidecar.json> --patch [--out file.v]   # fix a broken step live')
	eprintln('')
	eprintln('Web : records until you press Enter; Alt+click records an assertion.')
	eprintln('Android: tap the device/emulator; press Enter here to finish (UiA2 must be running).')
	eprintln('iOS : REPL - `tap x y`, `text <s>`, `assert x y`, `done` (WDA must be running).')
	eprintln('')
	eprintln('--update replays the sidecar live and reports which step (if any) no longer')
	eprintln('resolves, instead of recording a fresh flow. Recording always writes the')
	eprintln('sidecar (out + ".codegen.json") next to --out so a later run can audit it.')
	eprintln('')
	eprintln('--patch (with --update): on a broken step, drop back into live recording on')
	eprintln('the same session instead of stopping, splice the recorded replacement onto the')
	eprintln('good prefix, and write it back to --out (or, by default, the path the sidecar')
	eprintln('was written for). A broken .goto always still stops - see the code comment on')
	eprintln('audit_web for why.')
}

fn main() {
	args := os.args[1..]
	if args.len < 1 {
		usage()
		exit(2)
	}
	rest := args[1..]
	is_update := flag_value(rest, '--update', '') != ''
	patch := has_flag(rest, '--patch')
	match args[0] {
		'web' {
			if is_update {
				audit_web(rest, patch) or {
					eprintln('error: ${err}')
					exit(1)
				}
			} else {
				record_web(rest) or {
					eprintln('error: ${err}')
					exit(1)
				}
			}
		}
		'android' {
			if is_update {
				audit_android(rest, patch) or {
					eprintln('error: ${err}')
					exit(1)
				}
			} else {
				record_android(rest) or {
					eprintln('error: ${err}')
					exit(1)
				}
			}
		}
		'ios' {
			if is_update {
				audit_ios(rest, patch) or {
					eprintln('error: ${err}')
					exit(1)
				}
			} else {
				record_ios(rest) or {
					eprintln('error: ${err}')
					exit(1)
				}
			}
		}
		else {
			usage()
			exit(2)
		}
	}
}

// flag_value returns the value following `name` in args, or `def`.
fn flag_value(args []string, name string, def string) string {
	for i := 0; i < args.len - 1; i++ {
		if args[i] == name {
			return args[i + 1]
		}
	}
	return def
}

// has_flag reports whether a boolean (no-value) flag is present in args.
fn has_flag(args []string, name string) bool {
	return name in args
}

// derive_out_path resolves where a patched program should be written: an
// explicit --out wins; otherwise strip the '.codegen.json' suffix
// write_program appends, so `codegen ... --update flow.v.codegen.json
// --patch` writes back to flow.v (and a fresh sidecar) with no extra flags
// needed for the common case.
fn derive_out_path(sidecar_path string, explicit_out string) !string {
	if explicit_out != '' {
		return explicit_out
	}
	suffix := '.codegen.json'
	if sidecar_path.ends_with(suffix) {
		return sidecar_path[..sidecar_path.len - suffix.len]
	}
	return error('cannot derive an output path from ${sidecar_path}; pass --out explicitly')
}

// write_program prints the generated source to stdout, or writes it to `out`
// alongside a JSON sidecar (`out + '.codegen.json'`) holding the recorded
// actions — the persisted form a later `--update` run reloads to audit the
// flow against a changed page/app.
fn write_program(code string, acts []webdriver.RecordedAction, out string) ! {
	if out == '' {
		println(code)
		return
	}
	os.write_file(out, code)!
	sidecar := out + '.codegen.json'
	os.write_file(sidecar, webdriver.actions_to_json(acts))!
	eprintln('Wrote ${acts.len} actions to ${out} (sidecar: ${sidecar})')
}

fn record_web(args []string) ! {
	mut url := ''
	mut out := ''
	mut browser := 'edge'
	mut i := 0
	for i < args.len {
		a := args[i]
		if a == '--out' {
			if i + 1 >= args.len {
				return error('--out needs a path')
			}
			out = args[i + 1]
			i += 2
			continue
		}
		if a == '--browser' {
			if i + 1 >= args.len {
				return error('--browser needs a value')
			}
			browser = args[i + 1]
			i += 2
			continue
		}
		if url == '' {
			url = a
		}
		i++
	}
	if url == '' {
		return error('web requires a <url>')
	}

	opts := webdriver.LaunchOptions{
		headless: false
		bidi:     true
	}
	mut b := if browser == 'chrome' {
		webdriver.launch_chrome(opts)!
	} else {
		webdriver.launch_edge(opts)!
	}
	defer { b.close() }
	b.goto(url)!

	mut bidi := b.bidi()!
	defer { bidi.close() }
	mut rec := bidi.new_recorder()
	rec.start()!

	eprintln('Recording ${url} ... interact with the browser, then press Enter here to finish.')
	os.get_line()

	// The initial navigation is the first action; in-page interactions follow.
	mut acts := [webdriver.RecordedAction{
		kind:  .goto
		value: url
	}]
	acts << rec.actions()
	code := webdriver.emit_v_web(acts)
	write_program(code, acts, out)!
}

// first_adb_device returns the first device id reported by `adb devices`, or
// '' if none are attached.
fn first_adb_device() string {
	r := os.execute('adb devices')
	if r.exit_code != 0 {
		return ''
	}
	for line in r.output.split_into_lines() {
		l := line.trim_space()
		if l == '' || l.starts_with('List of devices') {
			continue
		}
		f := l.fields()
		if f.len >= 2 && f[1] == 'device' {
			return f[0]
		}
	}
	return ''
}

// record_android captures taps on an Android device/emulator (passive, via
// `adb getevent`) and emits a runnable mobile program. Requires the
// UiAutomator2 server reachable (for page_source) — typically you've already
// run an `am instrument` + `adb forward` setup, or are using launch_android.
fn record_android(args []string) ! {
	out := flag_value(args, '--out', '')
	uia2_url := flag_value(args, '--uia2-url', 'http://localhost:6790')
	mut udid := flag_value(args, '--udid', '')
	if udid == '' {
		udid = first_adb_device()
		if udid == '' {
			return error('no Android device found; start an emulator or pass --udid (see `adb devices`)')
		}
	}

	mut s := mobile.launch_android(mobile.AndroidOptions{
		mode:     .attach
		udid:     udid
		uia2_url: uia2_url
	})!
	s.device_udid = udid
	defer { s.close() }

	sw, sh := s.screen_size()!
	mx, my := s.touch_axis_max()!
	eprintln('Device ${udid}: ${sw}x${sh}, touch max ${mx}x${my}')

	mut rec := s.new_recorder()
	mut proc := s.start_touch_stream()!

	eprintln('Recording — tap on the device/emulator; press Enter here to finish.')
	t := spawn capture_taps(rec, proc, sw, sh, mx, my)
	os.get_line()
	proc.signal_kill()
	t.wait()

	rec.flush_pending_edit() or {}
	acts := rec.actions()
	write_program(rec.emit(), acts, out)!
}

// capture_taps reads the getevent stream line-by-line, scales each finger-up
// to screen pixels, and records a tap. Runs in its own thread; stops when the
// process is killed (on Enter from the main thread).
fn capture_taps(rec &mobile.MobileRecorder, p &os.Process, sw int, sh int, mx int, my int) {
	mut r := rec
	mut pp := p
	mut parser := mobile.GetEventParser{}
	mut buf := ''
	for pp.is_alive() {
		chunk := pp.stdout_read()
		if chunk == '' {
			continue
		}
		buf += chunk
		for {
			nl := buf.index('\n') or { break }
			line := buf[..nl]
			buf = buf[nl + 1..]
			if tap := parser.feed(line) {
				sx, sy := mobile.scale_point(tap.x, tap.y, mx, my, sw, sh)
				r.record_tap_at(sx, sy) or {
					eprintln('  (skipped tap at ${sx},${sy}: ${err})')
					continue
				}
				eprintln('  · tap (${sx}, ${sy})')
			}
		}
	}
}

// record_ios drives an assisted REPL: there is no passive touch stream on
// iOS, so the operator names targets and each is hit-tested against the
// current page source, performed, and recorded.
fn record_ios(args []string) ! {
	out := flag_value(args, '--out', '')
	wda_url := flag_value(args, '--wda-url', 'http://localhost:8100')
	bundle := flag_value(args, '--bundle', '')

	mut s := mobile.launch_ios(mobile.IOSOptions{
		mode:      .attach
		wda_url:   wda_url
		bundle_id: bundle
	})!
	defer { s.close() }

	mut rec := s.new_recorder()
	eprintln('iOS codegen REPL (WDA ${wda_url}). Commands:')
	run_ios_repl(mut s, rec)!

	rec.flush_pending_edit() or {}
	acts := rec.actions()
	write_program(rec.emit(), acts, out)!
}

// run_ios_repl drives the assisted REPL shared by fresh iOS capture
// (record_ios) and patch-mode iOS capture (patch_mobile): there's no passive
// touch stream on iOS, so the operator names targets and each is hit-tested
// against the current page source, performed, and recorded.
fn run_ios_repl(mut s mobile.MobileSession, rec &mobile.MobileRecorder) ! {
	mut r := rec
	eprintln('  tap <x> <y>     hit-test, tap, and record')
	eprintln('  text <string>   type into the last-tapped field and record a fill')
	eprintln('  assert <x> <y>  record an assert_visible')
	eprintln('  done            finish and emit')
	for {
		line := os.get_line().trim_space()
		if line == '' {
			continue
		}
		parts := line.fields()
		cmd := parts[0]
		match cmd {
			'done', 'quit', 'exit' {
				break
			}
			'tap' {
				if parts.len < 3 {
					eprintln('usage: tap <x> <y>')
					continue
				}
				x := parts[1].int()
				y := parts[2].int()
				r.record_tap_at(x, y) or {
					eprintln('  (${err})')
					continue
				}
				s.tap_at(x, y) or { eprintln('  (tap failed: ${err})') }
			}
			'text' {
				if line.len <= 5 {
					eprintln('usage: text <string>')
					continue
				}
				r.record_text(line[5..]) or { eprintln('  (${err})') }
			}
			'assert' {
				if parts.len < 3 {
					eprintln('usage: assert <x> <y>')
					continue
				}
				r.record_assert_at(parts[1].int(), parts[2].int()) or { eprintln('  (${err})') }
			}
			else {
				eprintln('unknown command: ${cmd}')
			}
		}
	}
}

// --- audit mode --------------------------------------------------------
//
// Replays a previously recorded flow (loaded from a --update sidecar) live
// and reports which step's locator no longer resolves, instead of only
// being able to re-record from scratch after a UI refactor. Stops at the
// first broken step since later steps depend on state the broken step
// would have produced.

// audit_web replays a recorded web flow against a live page. With `patch`,
// a broken locator (or a resolved-but-failing action) drops back into live
// recording on the same browser instead of stopping — see patch_web. A
// broken `.goto` still always stops: navigation-level breaks are a different
// failure class than a stale locator, and there's nothing sensible to
// auto-splice for a URL the recorder never observes.
fn audit_web(args []string, patch bool) ! {
	update := flag_value(args, '--update', '')
	if update == '' {
		return error('--update <sidecar.json> is required')
	}
	browser := flag_value(args, '--browser', 'edge')
	explicit_out := flag_value(args, '--out', '')

	acts := webdriver.actions_from_json(os.read_file(update)!)!
	if acts.len == 0 {
		return error('${update} has no recorded actions')
	}

	opts := webdriver.LaunchOptions{
		headless: false
		bidi:     patch
	}
	mut b := if browser == 'chrome' {
		webdriver.launch_chrome(opts)!
	} else {
		webdriver.launch_edge(opts)!
	}
	defer { b.close() }

	mut passed := 0
	for idx, a in acts {
		if a.kind == .goto {
			b.goto(a.value) or {
				report_broken(idx, acts.len, passed, '${a.kind} ${a.value}', err.msg())
				return error('audit stopped at step ${idx + 1}/${acts.len}')
			}
			eprintln('✓ step ${idx + 1}/${acts.len}: goto ${a.value}')
			passed++
			continue
		}
		n := b.wd.locator_for(a.target).count() or { 0 }
		reason := webdriver.locator_health(n, a.target.nth)
		if reason != '' {
			report_broken(idx, acts.len, passed, '${a.kind} [${a.target.kind} ${a.target.value}]',
				reason)
			if patch {
				return patch_web(mut b, acts, idx, update, explicit_out)
			}
			return error('audit stopped at step ${idx + 1}/${acts.len}')
		}
		b.perform_action(a) or {
			report_broken(idx, acts.len, passed, '${a.kind} [${a.target.kind} ${a.target.value}]',
				'resolved but failed to perform: ${err}')
			if patch {
				return patch_web(mut b, acts, idx, update, explicit_out)
			}
			return error('audit stopped at step ${idx + 1}/${acts.len}')
		}
		eprintln('✓ step ${idx + 1}/${acts.len}: ${a.kind}')
		passed++
	}
	eprintln('${passed}/${acts.len} steps OK — flow still resolves cleanly.')
}

// patch_web drops back into live recording from a broken step, on the
// browser already open and in the right state from replaying the successful
// prefix (`acts[..idx]`). Splices [old prefix] + [newly recorded suffix]
// into a fresh program + sidecar written to
// derive_out_path(sidecar_path, explicit_out) — by default the same paths
// the original recording used, so re-running --update afterward (without
// --patch) is the natural way to confirm the fix actually resolves cleanly.
fn patch_web(mut b webdriver.Browser, acts []webdriver.RecordedAction, idx int, sidecar_path string, explicit_out string) ! {
	out := derive_out_path(sidecar_path, explicit_out)!

	mut bidi := b.bidi()!
	defer { bidi.close() }
	mut rec := bidi.new_recorder()
	rec.start()!

	eprintln('Patch mode: interact with the browser to record a replacement, then press Enter here to finish.')
	os.get_line()

	mut new_acts := acts[..idx].clone()
	new_acts << rec.actions()
	code := webdriver.emit_v_web(new_acts)
	write_program(code, new_acts, out)!
}

// audit_android replays a recorded Android flow against the live device/emulator.
fn audit_android(args []string, patch bool) ! {
	update := flag_value(args, '--update', '')
	if update == '' {
		return error('--update <sidecar.json> is required')
	}
	explicit_out := flag_value(args, '--out', '')
	uia2_url := flag_value(args, '--uia2-url', 'http://localhost:6790')
	mut udid := flag_value(args, '--udid', '')
	if udid == '' {
		udid = first_adb_device()
		if udid == '' {
			return error('no Android device found; start an emulator or pass --udid (see `adb devices`)')
		}
	}

	acts := webdriver.actions_from_json(os.read_file(update)!)!
	if acts.len == 0 {
		return error('${update} has no recorded actions')
	}

	mut s := mobile.launch_android(mobile.AndroidOptions{
		mode:     .attach
		udid:     udid
		uia2_url: uia2_url
	})!
	s.device_udid = udid
	defer { s.close() }

	audit_mobile(mut s, acts, patch, update, explicit_out)!
}

// audit_ios replays a recorded iOS flow against the live device/simulator.
fn audit_ios(args []string, patch bool) ! {
	update := flag_value(args, '--update', '')
	if update == '' {
		return error('--update <sidecar.json> is required')
	}
	explicit_out := flag_value(args, '--out', '')
	wda_url := flag_value(args, '--wda-url', 'http://localhost:8100')
	bundle := flag_value(args, '--bundle', '')

	acts := webdriver.actions_from_json(os.read_file(update)!)!
	if acts.len == 0 {
		return error('${update} has no recorded actions')
	}

	mut s := mobile.launch_ios(mobile.IOSOptions{
		mode:      .attach
		wda_url:   wda_url
		bundle_id: bundle
	})!
	defer { s.close() }

	audit_mobile(mut s, acts, patch, update, explicit_out)!
}

// audit_mobile walks a recorded action list against a live mobile session,
// printing a per-step pass/fail report and stopping at the first broken
// locator. Shared by android and ios audit entry points since MobileSession
// is the same type once attached. Returns an error (rather than exiting
// directly) so the caller's `defer { s.close() }` still runs on a broken step
// — the common case — instead of leaking the live session. With `patch`, a
// broken step drops back into live recording (patch_mobile) instead of
// stopping.
fn audit_mobile(mut s mobile.MobileSession, acts []webdriver.RecordedAction, patch bool, sidecar_path string, explicit_out string) ! {
	mut passed := 0
	for idx, a in acts {
		if a.kind == .goto || a.kind == .select_option || a.kind == .press {
			eprintln('· step ${idx + 1}/${acts.len}: ${a.kind} — skipped (not supported on mobile)')
			passed++
			continue
		}
		n := (s.locator_for(a.target).find_all() or { []webdriver.ElementRef{} }).len
		reason := webdriver.locator_health(n, a.target.nth)
		if reason != '' {
			report_broken(idx, acts.len, passed, '${a.kind} [${a.target.kind} ${a.target.value}]',
				reason)
			if patch {
				return patch_mobile(mut s, acts, idx, sidecar_path, explicit_out)
			}
			return error('audit stopped at step ${idx + 1}/${acts.len}')
		}
		s.perform_action(a) or {
			report_broken(idx, acts.len, passed, '${a.kind} [${a.target.kind} ${a.target.value}]',
				'resolved but failed to perform: ${err}')
			if patch {
				return patch_mobile(mut s, acts, idx, sidecar_path, explicit_out)
			}
			return error('audit stopped at step ${idx + 1}/${acts.len}')
		}
		eprintln('✓ step ${idx + 1}/${acts.len}: ${a.kind}')
		passed++
	}
	eprintln('${passed}/${acts.len} steps OK — flow still resolves cleanly.')
}

// patch_mobile drops back into live recording from a broken step on an
// already-open mobile session, in the right state from replaying the
// successful prefix. Branches only on platform for the capture mechanism —
// Android's passive tap stream (reusing capture_taps) vs iOS's assisted REPL
// (reusing run_ios_repl) — and shares the splice/emit/write logic once a
// recorded suffix exists, same as patch_web.
fn patch_mobile(mut s mobile.MobileSession, acts []webdriver.RecordedAction, idx int, sidecar_path string, explicit_out string) ! {
	out := derive_out_path(sidecar_path, explicit_out)!
	mut rec := s.new_recorder()

	if s.platform == .android {
		sw, sh := s.screen_size()!
		mx, my := s.touch_axis_max()!
		mut proc := s.start_touch_stream()!
		eprintln('Patch mode: tap on the device/emulator to record a replacement, then press Enter here to finish.')
		t := spawn capture_taps(rec, proc, sw, sh, mx, my)
		os.get_line()
		proc.signal_kill()
		t.wait()
	} else {
		eprintln('Patch mode — iOS REPL to record a replacement:')
		run_ios_repl(mut s, rec)!
	}

	rec.flush_pending_edit() or {}
	mut new_acts := acts[..idx].clone()
	new_acts << rec.actions()
	plat := if s.platform == .ios { 'ios' } else { 'android' }
	code := webdriver.emit_v_mobile(new_acts, plat)
	write_program(code, new_acts, out)!
}

// report_broken prints the standard "step broke" report shared by all three
// audit entry points: which step, what it was, why, and how far the replay
// got before stopping.
fn report_broken(idx int, total int, passed int, step string, reason string) {
	eprintln('✗ step ${idx + 1}/${total}: ${step} — ${reason}')
	eprintln('${passed}/${total} steps OK; stopped at step ${idx + 1}')
}
