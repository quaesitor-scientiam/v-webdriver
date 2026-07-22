module mobile

import os
import time
import vebidor.webdriver

// Android bridge.
//
// adb handles both emulators and real devices uniformly (both appear in
// `adb devices`). The lifecycle:
//
//   1. Detect `adb` on PATH or via `$ANDROID_HOME/platform-tools/adb`.
//   2. `adb install -r` the two UiAutomator2-server APKs (idempotent —
//      `-r` reinstalls in place if the same version is already there).
//   3. Spawn `adb shell am instrument -w ...` as a long-running
//      subprocess — this starts the HTTP server on the device.
//   4. `adb forward tcp:6790 tcp:6790` to expose the device port locally.
//   5. Poll `/status` until UiA2 answers.
//
// On close():
//   - Kill the `am instrument` subprocess (killing adb tears down the
//     instrumentation on the device too).
//   - `adb forward --remove tcp:6790`.
//   - `adb shell am force-stop io.appium.uiautomator2.server` — belt-and-
//     suspenders in case the instrumentation outlives adb.
//
// The two APKs come from the appium/appium-uiautomator2-server GitHub
// releases. Pass paths via AndroidOptions.uia2_server_apk and
// AndroidOptions.uia2_server_test_apk.

const uia2_test_runner = 'io.appium.uiautomator2.server.test/androidx.test.runner.AndroidJUnitRunner'

const uia2_server_pkg = 'io.appium.uiautomator2.server'

// check_uia2_reachable hits UiA2's /status to confirm the server is up.
// Returns a clear error with launch instructions if not — much nicer
// than a cryptic "connection refused" out of `launch_android`. Used by
// the `.attach` launch mode.
pub fn check_uia2_reachable(base_url string) ! {
	transport := webdriver.HttpTransport{}
	resp := transport.execute('GET', '${base_url}/status', '', '') or {
		return error('UiAutomator2-server unreachable at ${base_url}.\n' + '\n' +
			'Start it before calling launch_android. Quick path:\n' +
			'  adb -s <udid> install -r appium-uiautomator2-server.apk\n' +
			'  adb -s <udid> install -r appium-uiautomator2-server-test.apk\n' +
			'  adb -s <udid> shell am instrument -w -e debug false \\\n' +
			'    ${uia2_test_runner} &\n' + '  adb -s <udid> forward tcp:6790 tcp:6790\n' + '\n' +
			'Or call `launch_android(AndroidOptions{ mode: .spawn, … })` to spawn it automatically.\n' +
			'Underlying error: ${err.msg()}')
	}
	if resp.status_code >= 400 {
		return error('UiA2-server at ${base_url} responded ${resp.status_code} on /status — is it healthy?')
	}
}

// wait_for_uia2 polls /status until it answers 2xx or `timeout_ms`
// elapses. Used after spawning the instrumentation so the launcher only
// returns once UiA2 is actually serving HTTP.
pub fn wait_for_uia2(base_url string, timeout_ms int) ! {
	transport := webdriver.HttpTransport{}
	start := time.now()
	for {
		if resp := transport.execute('GET', '${base_url}/status', '', '') {
			if resp.status_code < 400 {
				return
			}
		}
		if time.now().unix_milli() - start.unix_milli() > i64(timeout_ms) {
			return error('UiA2-server at ${base_url} did not respond within ${timeout_ms}ms')
		}
		time.sleep(500 * time.millisecond)
	}
}

// exe_suffix is the platform's executable extension. Needed because
// `os.exists` does no extension resolution of its own — on Windows,
// `platform-tools/adb` never exists, only `platform-tools/adb.exe`.
fn exe_suffix() string {
	$if windows {
		return '.exe'
	} $else {
		return ''
	}
}

// detect_adb returns the adb command to use — falls back to
// `$ANDROID_HOME/platform-tools/adb` or `$ANDROID_SDK_ROOT/platform-tools/adb`
// if adb isn't on PATH. Errors with a useful message if neither is
// available.
fn detect_adb() !string {
	if command_on_path('adb') {
		return 'adb'
	}
	for env_key in ['ANDROID_HOME', 'ANDROID_SDK_ROOT'] {
		val := os.getenv(env_key)
		if val == '' {
			continue
		}
		candidate := os.join_path(val, 'platform-tools', 'adb' + exe_suffix())
		if os.exists(candidate) {
			return candidate
		}
	}
	return error('adb not found on PATH and ANDROID_HOME / ANDROID_SDK_ROOT not set. Install the Android SDK and add platform-tools to PATH.')
}

// install_uia2 installs the two UiAutomator2-server APKs onto the
// targeted device. `adb install -r` is idempotent (replaces in place if
// the same version is already installed).
pub fn install_uia2(udid string, server_apk string, server_test_apk string) ! {
	adb := detect_adb()!
	if !os.exists(server_apk) {
		return error('uia2_server_apk not found: ${server_apk}')
	}
	if !os.exists(server_test_apk) {
		return error('uia2_server_test_apk not found: ${server_test_apk}')
	}
	r1 := os.execute('${adb} -s ${udid} install -r ${server_apk}')
	if r1.exit_code != 0 {
		return error('adb install ${server_apk} failed: ${r1.output.trim_space()}')
	}
	r2 := os.execute('${adb} -s ${udid} install -r ${server_test_apk}')
	if r2.exit_code != 0 {
		return error('adb install ${server_test_apk} failed: ${r2.output.trim_space()}')
	}
}

// start_uia2_server spawns `adb shell am instrument -w` to run the
// UiAutomator2-server instrumentation as a daemon. Returns the subprocess
// handle so the caller can kill it on close() — killing adb tears down
// the instrumentation on the device side as well.
pub fn start_uia2_server(udid string) !&os.Process {
	adb := detect_adb()!
	mut p := os.new_process(adb)
	p.set_args([
		'-s',
		udid,
		'shell',
		'am',
		'instrument',
		'-w',
		'-e',
		'debug',
		'false',
		uia2_test_runner,
	])
	p.set_redirect_stdio()
	p.run()
	return p
}

// forward_port runs `adb forward tcp:<port> tcp:<port>` so HTTP requests
// to `localhost:<port>` reach the on-device UiA2 server.
pub fn forward_port(udid string, port int) ! {
	adb := detect_adb()!
	res := os.execute('${adb} -s ${udid} forward tcp:${port} tcp:${port}')
	if res.exit_code != 0 {
		return error('adb forward tcp:${port} failed (exit ${res.exit_code}): ${res.output.trim_space()}')
	}
}
