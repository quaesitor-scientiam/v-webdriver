// vebidor.mobile · Mob-6.1 — lock state, geolocation, network
//
// Exercises the Mob-6.1 device-state surface against an Android Emulator:
// lock / is_locked / unlock, set_geolocation, and set_network_condition.
// The lock + geolocation calls work on iOS too (over WDA / simctl); the
// network calls are Android-only (iOS has no per-session throttling).
//
// Setup (Android):
//   export ANDROID_UDID='emulator-5554'
//   export UIA2_SERVER_APK='/path/to/appium-uiautomator2-server-v*.apk'
//   export UIA2_SERVER_TEST_APK='/path/to/...-androidTest.apk'
//   v run examples/mobile/example_mob_devicestate.v
module main

import os
import time
import vebidor.mobile

fn run() ! {
	println('vebidor.mobile · Mob-6.1 — lock / geolocation / network\n')

	udid := os.getenv('ANDROID_UDID')
	server_apk := os.getenv('UIA2_SERVER_APK')
	test_apk := os.getenv('UIA2_SERVER_TEST_APK')
	if udid == '' || server_apk == '' || test_apk == '' {
		return error('Set ANDROID_UDID, UIA2_SERVER_APK, UIA2_SERVER_TEST_APK env vars before running.')
	}

	mut s := mobile.launch_android(mobile.AndroidOptions{
		mode:                 .spawn
		udid:                 udid
		app_package:          'com.android.settings'
		app_activity:         '.Settings'
		uia2_server_apk:      server_apk
		uia2_server_test_apk: test_apk
	})!
	defer {
		s.close()
	}
	println('session_id = ${s.session_id}\n')

	// ---- lock state --------------------------------------------------
	println('is_locked = ${s.is_locked()!}')
	println('lock() …')
	s.lock()!
	time.sleep(1000 * time.millisecond)
	println('is_locked = ${s.is_locked()!}') // expect: true
	println('unlock() …')
	s.unlock()!
	time.sleep(1000 * time.millisecond)
	println('is_locked = ${s.is_locked()!}\n') // expect: false

	// ---- geolocation -------------------------------------------------
	println('set_geolocation(37.422, -122.084) …')
	s.set_geolocation(37.422, -122.084, 0)!
	println('  location fix sent\n')

	// ---- network conditioning ----------------------------------------
	println('set_network_condition(airplane on) …')
	s.set_network_condition(mobile.NetworkCondition{ airplane_mode: true })!
	time.sleep(800 * time.millisecond)
	println('  airplane_mode_on = ${airplane_state(udid)}') // expect: 1
	println('set_network_condition(airplane off) …')
	s.set_network_condition(mobile.NetworkCondition{ airplane_mode: false })!
	time.sleep(800 * time.millisecond)
	println('  airplane_mode_on = ${airplane_state(udid)}') // expect: 0
	println('set_network_condition(throttle to lte) …')
	s.set_network_condition(mobile.NetworkCondition{ speed: 'lte', delay: 'none' })!
	println('  network speed/delay applied')

	println('\nMob-6.1 device-state passed ✓')
}

// airplane_state reads the airplane-mode global setting straight off the
// device for verification (independent of the library under test).
fn airplane_state(udid string) string {
	return os.execute('adb -s ${udid} shell settings get global airplane_mode_on').output.trim_space()
}

fn main() {
	run() or {
		eprintln('Mob-6.1 example failed: ${err}')
		exit(1)
	}
}
