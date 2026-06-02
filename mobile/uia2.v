module mobile

import x.json2 as json

// UiAutomator2-server HTTP client. UiA2's wire shape is W3C-flavored just
// like WDA's, so the post / get / post_void / delete_void wrappers on
// MobileSession (defined in wda.v) and the element commands
// (find_element / click_element / send_keys / element_text / etc.)
// work for UiA2 unchanged.
//
// This file only adds the Android-specific session-create flow. UiA2-
// specific extensions (e.g. mobile: scroll commands beyond what W3C
// actions cover) land in follow-up phases.

// new_android_session opens a fresh UiAutomator2-server session and
// returns a MobileSession. Assumes the server is already running at
// `base_url` — the bridge that auto-launches it (`adb install` +
// `am instrument` + `adb forward`) lives in bridges_android.v and is
// called from `launch_android`.
pub fn new_android_session(base_url string, app_package string, app_activity string) !MobileSession {
	probe := MobileSession{
		platform: .android
		base_url: base_url
	}

	// W3C capabilities. UiA2-server requires the `appium:` vendor prefix
	// on driver-specific capabilities (per the W3C spec for non-standard
	// caps). platformName itself is W3C-standard.
	mut always_match := map[string]json.Any{}
	always_match['platformName'] = json.Any('Android')
	if app_package.len > 0 {
		always_match['appium:appPackage'] = json.Any(app_package)
	}
	if app_activity.len > 0 {
		always_match['appium:appActivity'] = json.Any(app_activity)
	}
	mut caps := map[string]json.Any{}
	caps['alwaysMatch'] = json.Any(always_match)
	caps['firstMatch'] = json.Any([json.Any(map[string]json.Any{})])
	mut req := map[string]json.Any{}
	req['capabilities'] = json.Any(caps)

	resp := probe.post[map[string]json.Any]('/session', json.Any(req))!
	sid_any := resp.value['sessionId'] or {
		return error('UiAutomator2 session response missing sessionId')
	}
	return MobileSession{
		platform:   .android
		base_url:   base_url
		session_id: sid_any.str()
		app_id:     app_package
	}
}
