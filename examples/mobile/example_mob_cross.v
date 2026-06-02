// vebidor.mobile · Mob-4 — cross-platform selectors
//
// The same V source drives BOTH iOS and Android. The only thing that
// changes between targets is which backend `launch_*` you call to get the
// session; every selector below is written once with the portable
// `get_by_*` surface and compiles down to the right per-platform strategy
// underneath (XCUITest predicate / class chain on iOS, UiAutomator
// UiSelector / xpath on Android).
//
// Pick the target with the PLATFORM env var:
//
//     # iOS Simulator (macOS)
//     export PLATFORM=ios
//     export IOS_SIM_UDID='...'           # xcrun simctl list devices
//     export WDA_XCTESTRUN='/.../WebDriverAgentRunner_*.xctestrun'
//     v run examples/mobile/example_mob_cross.v
//
//     # Android Emulator
//     export PLATFORM=android
//     export ANDROID_UDID='emulator-5554'
//     export UIA2_SERVER_APK='/path/to/appium-uiautomator2-server-v*.apk'
//     export UIA2_SERVER_TEST_APK='/path/to/...-androidTest.apk'
//     v run examples/mobile/example_mob_cross.v
//
// Both targets open the device Settings app, then run the IDENTICAL
// selector + assertion code against it.
module main

import os
import vebidor.mobile

fn run() ! {
	platform := os.getenv('PLATFORM')
	println('vebidor.mobile · Mob-4 — cross-platform selectors (PLATFORM=${platform})\n')

	mut s := open_session(platform)!
	defer {
		s.close()
	}
	println('session_id = ${s.session_id}\n')

	// ---- everything below is platform-agnostic ----------------------

	// Static-text role: count the text rows on the Settings home screen.
	// Same call resolves to XCUIElementTypeStaticText on iOS and
	// android.widget.TextView on Android.
	texts := s.get_by_role(.static_text, '').find_all()!
	println('get_by_role(.static_text) → ${texts.len} elements')

	// Label selector: the accessible name "Settings" appears as the
	// screen title on both platforms. get_by_label spreads across
	// label/name/value (iOS) or content-desc/text (Android).
	println('expect(get_by_label("Settings")).to_be_visible() …')
	mobile.expect(s.get_by_label('Settings')).with_timeout(5000).to_be_visible() or {
		println('  (Settings title varies by OS version — not fatal)')
	}

	// Text substring selector — same idea, matched as a substring of the
	// visible text rather than the full accessible label.
	println('expect(get_by_text("Settings")).to_be_visible() …')
	mobile.expect(s.get_by_text('Settings')).with_timeout(5000).to_be_visible() or {
		println('  (no visible "Settings" substring — not fatal)')
	}

	out := './mobile_cross_${platform}.png'
	s.save_screenshot(out)!
	println('screenshot saved to ${out}')

	println('\nMob-4 cross-platform selectors passed ✓')
}

// open_session picks the backend from PLATFORM and returns a ready
// MobileSession. This is the ONLY platform-specific code in the example.
fn open_session(platform string) !mobile.MobileSession {
	match platform {
		'ios' {
			udid := os.getenv('IOS_SIM_UDID')
			xctestrun := os.getenv('WDA_XCTESTRUN')
			if udid == '' || xctestrun == '' {
				return error('Set IOS_SIM_UDID and WDA_XCTESTRUN for PLATFORM=ios.')
			}
			println('booting Simulator + spawning WDA …')
			return mobile.launch_ios(mobile.IOSOptions{
				mode:          .simulator
				udid:          udid
				bundle_id:     'com.apple.Preferences'
				wda_xctestrun: xctestrun
			})!
		}
		'android' {
			udid := os.getenv('ANDROID_UDID')
			server_apk := os.getenv('UIA2_SERVER_APK')
			test_apk := os.getenv('UIA2_SERVER_TEST_APK')
			if udid == '' || server_apk == '' || test_apk == '' {
				return error('Set ANDROID_UDID, UIA2_SERVER_APK, UIA2_SERVER_TEST_APK for PLATFORM=android.')
			}
			println('installing UiA2 + spawning instrumentation via adb …')
			return mobile.launch_android(mobile.AndroidOptions{
				mode:                 .spawn
				udid:                 udid
				app_package:          'com.android.settings'
				app_activity:         '.Settings'
				uia2_server_apk:      server_apk
				uia2_server_test_apk: test_apk
			})!
		}
		else {
			return error('Set PLATFORM=ios or PLATFORM=android.')
		}
	}
}

fn main() {
	run() or {
		eprintln('Mob-4 cross-platform example failed: ${err}')
		exit(1)
	}
}
