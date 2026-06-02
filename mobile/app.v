module mobile

import os
import time
import x.json2 as json

// App lifecycle + management. The two backends diverge here: WDA exposes
// app launch/terminate/state over HTTP (`/wda/apps/*`), but the
// UiAutomator2 server does NOT — those endpoints return "unknown command"
// (404). On Android, Appium's own driver drives app lifecycle through
// adb, and so do we. Hence the per-platform split: iOS goes over the WDA
// socket, Android shells out to `adb -s <udid>`.
//
// `install_app` / `remove_app` on iOS are deliberately not implemented
// over WDA (WDA has no install endpoint); use `xcrun simctl install` for
// the Simulator or `go-ios` for a real device. They work on Android.

// AppState is the coarse run state of an application, normalized across
// the two backends. WDA reports a 0–4 integer; adb is queried for the
// equivalent on Android.
pub enum AppState {
	not_installed
	not_running
	background
	foreground
}

// activate_app brings the app to the foreground, launching it if it isn't
// already running.
//
// - iOS: WDA `POST /wda/apps/launch {bundleId}`.
// - Android: `adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1`.
pub fn (s MobileSession) activate_app(app_id string) ! {
	match s.platform {
		.ios {
			s.post_void('/session/${s.session_id}/wda/apps/launch', bundle_payload(app_id))!
		}
		.android {
			// Resolve the package's launchable component and `am start` it.
			// Preferred over `monkey`, which returns a bogus non-zero exit
			// code even on success.
			comp := s.resolve_launch_component(app_id) or {
				// Fallback: monkey launches by package alone. Its exit code
				// is unreliable, so don't gate on it.
				s.adb_prefix_exec_soft('shell monkey -p ${app_id} -c android.intent.category.LAUNCHER 1')
				return
			}
			s.adb_exec('shell am start -n ${comp}')!
		}
	}
}

// resolve_launch_component asks the package manager for the package's
// launchable activity, returning a `package/activity` component string.
fn (s MobileSession) resolve_launch_component(app_id string) !string {
	out := s.adb_capture('shell cmd package resolve-activity --brief ${app_id}')!
	lines := out.split_into_lines().filter(it.trim_space() != '')
	if lines.len > 0 {
		last := lines.last().trim_space()
		if last.contains('/') {
			return last
		}
	}
	return error('no launchable activity for ${app_id}')
}

// terminate_app force-quits the app.
//
// - iOS: WDA `POST /wda/apps/terminate {bundleId}`.
// - Android: `adb shell am force-stop <pkg>`.
pub fn (s MobileSession) terminate_app(app_id string) ! {
	match s.platform {
		.ios {
			s.post_void('/session/${s.session_id}/wda/apps/terminate', bundle_payload(app_id))!
		}
		.android {
			s.adb_exec('shell am force-stop ${app_id}')!
		}
	}
}

// query_app_state reports whether the app is installed, and if so whether
// it is not running, backgrounded, or foregrounded.
//
// - iOS: WDA `POST /wda/apps/state {bundleId}` → 0..4, normalized.
// - Android: `pm list packages` (installed?), `pidof` (running?),
//   `dumpsys activity` top-resumed line (foreground?).
pub fn (s MobileSession) query_app_state(app_id string) !AppState {
	match s.platform {
		.ios {
			resp := s.post[int]('/session/${s.session_id}/wda/apps/state', bundle_payload(app_id))!
			return match resp.value {
				4 { AppState.foreground }
				2, 3 { AppState.background }
				1 { AppState.not_running }
				else { AppState.not_installed }
			}
		}
		.android {
			pkgs := s.adb_capture('shell pm list packages ${app_id}')!
			if !pkgs.contains('package:${app_id}') {
				return AppState.not_installed
			}
			// `pidof` exits 1 when the process isn't found — that's the
			// "not running" signal, not an error, so capture softly.
			pid := s.adb_capture_soft('shell pidof ${app_id}').trim_space()
			if pid == '' {
				return AppState.not_running
			}
			top := s.adb_capture('shell dumpsys activity activities')!
			for line in top.split_into_lines() {
				if line.contains('topResumedActivity') || line.contains('ResumedActivity') {
					if line.contains(app_id) {
						return AppState.foreground
					}
				}
			}
			return AppState.background
		}
	}
}

// background_app sends the app to the background for `seconds`, then
// reactivates it (the session's own app, `s.app_id`). Pass a negative
// `seconds` to leave it backgrounded indefinitely.
//
// - iOS: WDA `POST /wda/deactivateApp {duration}`.
// - Android: HOME keyevent, sleep, then re-launch `s.app_id`.
pub fn (s MobileSession) background_app(seconds int) ! {
	match s.platform {
		.ios {
			mut params := map[string]json.Any{}
			params['duration'] = json.Any(seconds)
			s.post_void('/session/${s.session_id}/wda/deactivateApp', json.Any(params))!
		}
		.android {
			s.adb_exec('shell input keyevent KEYCODE_HOME')!
			if seconds >= 0 {
				time.sleep(seconds * time.second)
				if s.app_id != '' {
					s.activate_app(s.app_id)!
				}
			}
		}
	}
}

// install_app installs an app package from a local path. Android only
// (`adb install -r <path>`); on iOS install via `xcrun simctl install`
// (Simulator) or `go-ios` (device) — WDA has no install endpoint.
pub fn (s MobileSession) install_app(path string) ! {
	if s.platform != .android {
		return error('install_app is Android-only; on iOS use `xcrun simctl install <udid> ${path}` (Simulator) or go-ios (device)')
	}
	if !os.exists(path) {
		return error('install_app: file not found: ${path}')
	}
	s.adb_exec('install -r ${path}')!
}

// remove_app uninstalls an app by id. Android only (`adb uninstall`);
// on iOS use `xcrun simctl uninstall` / go-ios.
pub fn (s MobileSession) remove_app(app_id string) ! {
	if s.platform != .android {
		return error('remove_app is Android-only; on iOS use `xcrun simctl uninstall <udid> ${app_id}` (Simulator) or go-ios (device)')
	}
	s.adb_exec('uninstall ${app_id}')!
}

// bundle_payload builds the `{bundleId: ...}` body WDA's app endpoints take.
fn bundle_payload(bundle_id string) json.Any {
	mut params := map[string]json.Any{}
	params['bundleId'] = json.Any(bundle_id)
	return json.Any(params)
}

// adb_prefix returns the adb invocation targeting this session's device,
// e.g. `adb -s emulator-5554`. Falls back to bare `adb` when no udid is
// stored (single-device case).
fn (s MobileSession) adb_prefix() string {
	adb := detect_adb() or { 'adb' }
	return if s.device_udid != '' { '${adb} -s ${s.device_udid}' } else { adb }
}

// adb_exec runs an adb subcommand and errors on non-zero exit.
fn (s MobileSession) adb_exec(args string) ! {
	cmd := '${s.adb_prefix()} ${args}'
	r := os.execute(cmd)
	if r.exit_code != 0 {
		return error('adb failed (exit ${r.exit_code}): ${cmd}\n${r.output.trim_space()}')
	}
}

// adb_prefix_exec_soft runs an adb subcommand and ignores its exit code —
// for tools like `monkey` that return non-zero even on success.
fn (s MobileSession) adb_prefix_exec_soft(args string) {
	os.execute('${s.adb_prefix()} ${args}')
}

// adb_capture runs an adb subcommand and returns its stdout, erroring on
// non-zero exit.
fn (s MobileSession) adb_capture(args string) !string {
	cmd := '${s.adb_prefix()} ${args}'
	r := os.execute(cmd)
	if r.exit_code != 0 {
		return error('adb failed (exit ${r.exit_code}): ${cmd}\n${r.output.trim_space()}')
	}
	return r.output
}

// adb_capture_soft runs an adb subcommand and returns its stdout
// regardless of exit code — for probes like `pidof` that signal state
// through a non-zero exit rather than an error.
fn (s MobileSession) adb_capture_soft(args string) string {
	return os.execute('${s.adb_prefix()} ${args}').output
}
