module mobile

import os

// IOSLaunchMode selects how `launch_ios` finds (or starts) WebDriverAgent.
//
//   - `.attach`    — connect to a WDA that's already running at `wda_url`.
//                    Same behavior as Mob-2 first cut. Use this when you
//                    manage WDA yourself (CI, Appium-style setups).
//   - `.simulator` — boot the named iOS Simulator + spawn WDA via
//                    `xcodebuild test-without-building` against the
//                    provided .xctestrun. macOS host required.
//   - `.device`    — install WDA on a real iPhone via `go-ios install` (if
//                    the .ipa is provided), then `go-ios runwda` + port
//                    forward. macOS host + signed WDA .ipa required.
pub enum IOSLaunchMode {
	attach
	simulator
	device
}

// IOSOptions configures `launch_ios`.
//
// Required by mode:
//   `.attach`    — none (wda_url defaults to http://localhost:8100).
//   `.simulator` — `udid` + `wda_xctestrun`.
//   `.device`    — `udid` + `wda_ipa` (for first install).
pub struct IOSOptions {
pub:
	mode      IOSLaunchMode = .attach
	udid      string
	bundle_id string

	// Connection point. Used as-is by `.attach`; set automatically from
	// `wda_port` for the spawn modes.
	wda_url string = 'http://localhost:8100'

	// Spawn-mode configuration.
	wda_port             int = 8100
	wda_xctestrun        string // path to WebDriverAgentRunner_*.xctestrun (.simulator)
	wda_ipa              string // path to WebDriverAgentRunner.ipa        (.device)
	boot_sim             bool = true
	wda_ready_timeout_ms int  = 60_000

	// .device options
	app_path    string
	install_app bool
}

// AndroidLaunchMode selects how `launch_android` finds (or starts) the
// UiAutomator2 server.
//
//   - `.attach` — connect to a UiA2 server already running at `uia2_url`.
//                 Use this when you manage UiA2 yourself (CI, Appium-style
//                 setups).
//   - `.spawn`  — `adb install -r` both APKs, spawn `adb shell am
//                 instrument -w …`, `adb forward tcp:<port> tcp:<port>`,
//                 poll /status. Works for both emulators and real devices
//                 (adb handles them uniformly). Requires `adb` on PATH or
//                 `$ANDROID_HOME/platform-tools/adb`.
pub enum AndroidLaunchMode {
	attach
	spawn
}

// AndroidOptions configures `launch_android`. `udid` matches what
// `adb devices` reports. `app_package` and `app_activity` identify the
// app under test.
pub struct AndroidOptions {
pub:
	mode         AndroidLaunchMode = .attach
	udid         string
	app_package  string
	app_activity string

	// Connection point. Used as-is by `.attach`; set automatically from
	// `uia2_port` for `.spawn`.
	uia2_url string = 'http://localhost:6790'

	// `.spawn` configuration. The two APKs are from the
	// appium/appium-uiautomator2-server GitHub releases.
	uia2_port             int = 6790
	uia2_server_apk       string // path to appium-uiautomator2-server.apk
	uia2_server_test_apk  string // path to appium-uiautomator2-server-test.apk
	uia2_ready_timeout_ms int = 60_000

	apk_path    string
	install_app bool
}

// launch_ios opens a session against WebDriverAgent and returns a
// MobileSession. The launch mode (attach / simulator / device) controls
// whether WDA is expected to be already running or spawned by the
// launcher itself.
pub fn launch_ios(opts IOSOptions) !MobileSession {
	match opts.mode {
		.attach { return launch_ios_attach(opts) }
		.simulator { return launch_ios_simulator(opts) }
		.device { return launch_ios_device(opts) }
	}
}

// launch_ios_attach connects to an already-running WDA at `wda_url`.
fn launch_ios_attach(opts IOSOptions) !MobileSession {
	wda_url := if opts.wda_url.len > 0 { opts.wda_url } else { 'http://localhost:8100' }
	check_wda_reachable(wda_url)!
	return new_ios_session(wda_url, opts.bundle_id)
}

// launch_ios_simulator boots the named Simulator (idempotent), spawns
// `xcodebuild test-without-building`, polls /status until WDA answers,
// then opens a session. The xcodebuild process handle is stored on the
// returned MobileSession so close() kills it cleanly.
fn launch_ios_simulator(opts IOSOptions) !MobileSession {
	if opts.boot_sim {
		boot_simulator(opts.udid)!
	}
	proc := start_wda_simulator(opts.udid, opts.wda_xctestrun)!
	mut procs := [proc]

	port := if opts.wda_port > 0 { opts.wda_port } else { 8100 }
	base_url := 'http://localhost:${port}'

	wait_for_wda(base_url, opts.wda_ready_timeout_ms) or {
		kill_all(mut procs)
		return error('WDA failed to come up on ${base_url}: ${err.msg()}')
	}

	mut s := new_ios_session(base_url, opts.bundle_id) or {
		kill_all(mut procs)
		return err
	}
	s.bridge_procs = procs
	s.owns_bridge = true
	return s
}

// launch_ios_device runs `go-ios runwda` + `go-ios forward 8100 8100`
// against a real device, polls /status until WDA answers, then opens a
// session. Both process handles are stored on the returned MobileSession
// so close() kills both.
fn launch_ios_device(opts IOSOptions) !MobileSession {
	port := if opts.wda_port > 0 { opts.wda_port } else { 8100 }
	mut procs := start_wda_device(opts.udid, opts.wda_ipa, port)!

	base_url := 'http://localhost:${port}'

	wait_for_wda(base_url, opts.wda_ready_timeout_ms) or {
		kill_all(mut procs)
		return error('WDA failed to come up on ${base_url}: ${err.msg()}')
	}

	mut s := new_ios_session(base_url, opts.bundle_id) or {
		kill_all(mut procs)
		return err
	}
	s.bridge_procs = procs
	s.owns_bridge = true
	return s
}

// kill_all is the cleanup hook used when a bridge spawn succeeds but a
// later step (wait_for_wda / session create) fails. Without it the
// processes would outlive the launcher and have to be killed by hand.
fn kill_all(mut procs []&os.Process) {
	for mut p in procs {
		p.signal_kill()
		p.close()
	}
}

// launch_android opens a session against the UiAutomator2 server on an
// Android device or emulator and returns a MobileSession. The launch
// mode (attach / spawn) controls whether UiA2 is expected to be already
// running or spawned by the launcher itself.
pub fn launch_android(opts AndroidOptions) !MobileSession {
	match opts.mode {
		.attach { return launch_android_attach(opts) }
		.spawn { return launch_android_spawn(opts) }
	}
}

// launch_android_attach connects to an already-running UiA2 server.
fn launch_android_attach(opts AndroidOptions) !MobileSession {
	uia2_url := if opts.uia2_url.len > 0 { opts.uia2_url } else { 'http://localhost:6790' }
	check_uia2_reachable(uia2_url)!
	return new_android_session(uia2_url, opts.app_package, opts.app_activity)
}

// launch_android_spawn installs the UiA2 APKs (if paths provided), starts
// `am instrument`, sets up port forwarding, polls /status until UiA2
// answers, then opens a session. The instrumentation subprocess is stored
// on the returned MobileSession so close() kills it; `adb forward
// --remove` runs from on_close_cmds.
fn launch_android_spawn(opts AndroidOptions) !MobileSession {
	if opts.udid == '' {
		return error('AndroidOptions.udid required for .spawn mode (use `adb devices` to find one).')
	}
	port := if opts.uia2_port > 0 { opts.uia2_port } else { 6790 }

	if opts.uia2_server_apk != '' && opts.uia2_server_test_apk != '' {
		install_uia2(opts.udid, opts.uia2_server_apk, opts.uia2_server_test_apk)!
	}

	proc := start_uia2_server(opts.udid)!
	mut procs := [proc]

	forward_port(opts.udid, port) or {
		kill_all(mut procs)
		return error('adb forward failed: ${err.msg()}')
	}

	base_url := 'http://localhost:${port}'
	wait_for_uia2(base_url, opts.uia2_ready_timeout_ms) or {
		kill_all(mut procs)
		return error('UiA2-server failed to come up on ${base_url}: ${err.msg()}')
	}

	mut s := new_android_session(base_url, opts.app_package, opts.app_activity) or {
		kill_all(mut procs)
		return err
	}
	s.bridge_procs = procs
	s.owns_bridge = true
	s.device_udid = opts.udid

	// On close: release the port forward and force-stop the UiA2 server
	// on the device. Best-effort — failures here are not fatal because
	// the kernel will reclaim everything when adb dies.
	adb := detect_adb() or { 'adb' }
	s.on_close_cmds = [
		'${adb} -s ${opts.udid} forward --remove tcp:${port}',
		'${adb} -s ${opts.udid} shell am force-stop ${uia2_server_pkg}',
	]
	return s
}
