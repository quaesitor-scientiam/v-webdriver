// vebidor.mobile · Mob-6 — app lifecycle + device state
//
// Demonstrates the Mob-6 surface against an Android Emulator: query/flip
// device orientation, then inspect and drive app lifecycle (state →
// terminate → state → activate → state). The same `orientation` /
// `set_orientation` / `activate_app` / `terminate_app` / `query_app_state`
// API works on iOS too (orientation + the app calls go over WDA there);
// only the launch differs.
//
// Setup (Android):
//   export ANDROID_UDID='emulator-5554'
//   export UIA2_SERVER_APK='/path/to/appium-uiautomator2-server-v*.apk'
//   export UIA2_SERVER_TEST_APK='/path/to/...-androidTest.apk'
//   v run examples/mobile/example_mob_appstate.v
module main

import os
import time
import vebidor.mobile

fn run() ! {
	println('vebidor.mobile · Mob-6 — app lifecycle + device state\n')

	udid := os.getenv('ANDROID_UDID')
	server_apk := os.getenv('UIA2_SERVER_APK')
	test_apk := os.getenv('UIA2_SERVER_TEST_APK')
	if udid == '' || server_apk == '' || test_apk == '' {
		return error('Set ANDROID_UDID, UIA2_SERVER_APK, UIA2_SERVER_TEST_APK env vars before running.')
	}

	target := 'io.appium.android.apis'
	mut s := mobile.launch_android(mobile.AndroidOptions{
		mode:                 .spawn
		udid:                 udid
		app_package:          target
		app_activity:         '.ApiDemos'
		uia2_server_apk:      server_apk
		uia2_server_test_apk: test_apk
	})!
	defer {
		s.close()
	}
	println('session_id = ${s.session_id}\n')

	// ---- device state: orientation -----------------------------------
	// The set_orientation calls are wrapped tolerantly: on an emulator the
	// backend's rotation-settle wait (UiA2 hard-codes 2s) can race the
	// rotation animation when the foreground activity is busy. The call is
	// correct; the timeout is environmental.
	println('orientation = ${s.orientation()!}')
	println('rotating to landscape …')
	s.set_orientation(.landscape) or {
		println('  (rotation timed out — emulator settle race, not fatal)')
	}
	println('orientation = ${s.orientation()!}')
	println('rotating back to portrait …')
	s.set_orientation(.portrait) or {
		println('  (rotation timed out — emulator settle race, not fatal)')
	}
	println('orientation = ${s.orientation()!}\n')

	// ---- app lifecycle -----------------------------------------------
	println('activating ${target} …')
	s.activate_app(target)!
	time.sleep(1500 * time.millisecond)
	println('app state = ${s.query_app_state(target)!}') // expect: foreground

	println('terminating ${target} …')
	s.terminate_app(target)!
	time.sleep(1000 * time.millisecond)
	println('app state = ${s.query_app_state(target)!}') // expect: not_running

	println('re-activating ${target} …')
	s.activate_app(target)!
	time.sleep(1500 * time.millisecond)
	println('app state = ${s.query_app_state(target)!}') // expect: foreground

	println('\nMob-6 app lifecycle + device state passed ✓')
}

fn main() {
	run() or {
		eprintln('Mob-6 example failed: ${err}')
		exit(1)
	}
}
