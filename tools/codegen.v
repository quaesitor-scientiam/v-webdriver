module main

import vebidor.webdriver
import os

// vebidor codegen CLI — record a live browser session and emit a runnable
// vebidor test. Launches a headed browser, injects the recorder over BiDi,
// records your interactions, and (when you press Enter in the terminal) writes
// the generated V program.
//
//   v run tools/codegen.v web <url> [--out file.v] [--browser edge|chrome]
//
// Mobile capture (android/ios) is planned — it needs the native a11y-hit-test
// capture layer; see MOBILE_PLAN.md.

fn usage() {
	eprintln('vebidor codegen - record a browser session into a vebidor test')
	eprintln('')
	eprintln('Usage:')
	eprintln('  v run tools/codegen.v web <url> [--out file.v] [--browser edge|chrome]')
	eprintln('')
	eprintln('Records until you press Enter in this terminal, then writes the program.')
	eprintln('Tip: hold Alt while clicking an element to record an assertion instead of a click.')
	eprintln('Mobile capture (android/ios) is planned; see MOBILE_PLAN.md.')
}

fn main() {
	args := os.args[1..]
	if args.len < 1 {
		usage()
		exit(2)
	}
	match args[0] {
		'web' {
			record_web(args[1..]) or {
				eprintln('error: ${err}')
				exit(1)
			}
		}
		'android', 'ios' {
			eprintln('mobile codegen is not available yet (needs the native capture layer); see MOBILE_PLAN.md')
			exit(2)
		}
		else {
			usage()
			exit(2)
		}
	}
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
	if out == '' {
		println(code)
	} else {
		os.write_file(out, code)!
		eprintln('Wrote ${acts.len} actions to ${out}')
	}
}
