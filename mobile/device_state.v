module mobile

import os
import x.json2 as json

// Mob-6.1 — lock state, geolocation, and network conditioning.
//
// Like the rest of device/app management, the two backends diverge by what
// each natively exposes. Empirical probing of UiAutomator2-server v10.2.1
// showed it 404s on /lock, /location, and /network_connection, so every
// Android path here is adb-driven; iOS uses WDA's HTTP endpoints where they
// exist and falls back to host tooling (`xcrun simctl`) otherwise.
//
// Known limitations (deliberate, documented):
//   - Android unlock dismisses a *non-secure* keyguard only; PIN / pattern
//     / password unlock is out of scope.
//   - set_geolocation on Android uses the emulator console (`adb emu geo
//     fix`) — emulator only; real devices need a mock-location provider.
//   - set_network_condition is Android-only; iOS has no per-session network
//     throttling (use the host Network Link Conditioner).

// lock turns the screen off / locks the device.
//
// - iOS: WDA `POST /wda/lock`.
// - Android: `adb shell input keyevent 223` (KEYCODE_SLEEP) — non-toggling,
//   so it's a no-op if already asleep rather than waking the screen.
pub fn (s MobileSession) lock() ! {
	match s.platform {
		.ios {
			s.post_void('/session/${s.session_id}/wda/lock', empty_payload())!
		}
		.android {
			s.adb_exec('shell input keyevent 223')!
		}
	}
}

// unlock wakes the screen and dismisses a non-secure keyguard.
//
// - iOS: WDA `POST /wda/unlock`.
// - Android: `keyevent 224` (KEYCODE_WAKEUP) then `wm dismiss-keyguard`.
//   Does NOT enter a PIN / pattern / password — secure unlock is out of
//   scope.
pub fn (s MobileSession) unlock() ! {
	match s.platform {
		.ios {
			s.post_void('/session/${s.session_id}/wda/unlock', empty_payload())!
		}
		.android {
			s.adb_exec('shell input keyevent 224')!
			s.adb_exec('shell wm dismiss-keyguard')!
		}
	}
}

// is_locked reports whether the device is locked / its screen is off.
//
// - iOS: WDA `GET /wda/locked` → bool.
// - Android: locked if the screen is asleep (`dumpsys power`
//   `mWakefulness` is Asleep/Dozing) or the keyguard is showing
//   (`dumpsys window` `isKeyguardShowing=true`).
pub fn (s MobileSession) is_locked() !bool {
	match s.platform {
		.ios {
			resp := s.get_request[bool]('/session/${s.session_id}/wda/locked')!
			return resp.value
		}
		.android {
			power := s.adb_capture_soft('shell dumpsys power')
			asleep := power.contains('mWakefulness=Asleep') || power.contains('mWakefulness=Dozing')
			win := s.adb_capture_soft('shell dumpsys window')
			keyguard := win.contains('isKeyguardShowing=true')
			return asleep || keyguard
		}
	}
}

// set_geolocation sets the device's simulated location.
//
// - iOS: `xcrun simctl location <udid> set <lat>,<lng>` — needs the
//   Simulator udid, so the session must have been launched via
//   launch_ios(.simulator) / (.device).
// - Android: `adb emu geo fix <lng> <lat> <alt>` — EMULATOR ONLY (the
//   emulator console). Real devices need a mock-location provider, which
//   is out of scope. Note the lng,lat argument order the console expects.
pub fn (s MobileSession) set_geolocation(latitude f64, longitude f64, altitude f64) ! {
	match s.platform {
		.ios {
			if s.device_udid == '' {
				return error('set_geolocation on iOS needs the Simulator udid; only sessions launched via launch_ios(.simulator)/(.device) carry it')
			}
			r := os.execute('xcrun simctl location ${s.device_udid} set ${latitude},${longitude}')
			if r.exit_code != 0 {
				return error('simctl location failed (exit ${r.exit_code}): ${r.output.trim_space()}')
			}
		}
		.android {
			// emulator console wants longitude first, then latitude.
			s.adb_exec('emu geo fix ${longitude} ${latitude} ${altitude}')!
		}
	}
}

// NetworkCondition selects which radios / conditions to change. Unset
// (none) fields are left untouched; `speed` / `delay` are skipped when
// empty. All of these are Android emulator/device controls.
pub struct NetworkCondition {
pub:
	airplane_mode ?bool  // toggle airplane mode
	wifi          ?bool  // enable/disable Wi-Fi
	data          ?bool  // enable/disable mobile data
	speed         string // `adb emu network speed <profile>` (e.g. 'lte', 'gsm', 'full')
	delay         string // `adb emu network delay <profile>` (e.g. 'none', 'gprs')
}

// set_network_condition changes the device's network state. Android-only:
// iOS has no per-session network throttling (use the host Network Link
// Conditioner). Each field is applied independently; unset radio toggles
// are left as-is and empty speed/delay are skipped. `speed` / `delay` are
// emulator-console controls (emulator only).
pub fn (s MobileSession) set_network_condition(cond NetworkCondition) ! {
	if s.platform != .android {
		return error('set_network_condition is Android-only; iOS has no per-session network throttling (use the host Network Link Conditioner)')
	}
	if am := cond.airplane_mode {
		s.adb_exec('shell cmd connectivity airplane-mode ${enable_disable(am)}')!
	}
	if w := cond.wifi {
		s.adb_exec('shell svc wifi ${enable_disable(w)}')!
	}
	if d := cond.data {
		s.adb_exec('shell svc data ${enable_disable(d)}')!
	}
	if cond.speed != '' {
		s.adb_exec('emu network speed ${cond.speed}')!
	}
	if cond.delay != '' {
		s.adb_exec('emu network delay ${cond.delay}')!
	}
}

// empty_payload is the `{}` body WDA's lock/unlock endpoints accept.
fn empty_payload() json.Any {
	return json.Any(map[string]json.Any{})
}

// enable_disable renders a bool as the `enable`/`disable` argument shared
// by `svc` and `cmd connectivity airplane-mode`.
fn enable_disable(b bool) string {
	return if b { 'enable' } else { 'disable' }
}
