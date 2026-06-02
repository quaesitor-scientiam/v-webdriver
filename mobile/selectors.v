module mobile

// Cross-platform semantic selectors — the Playwright-style surface that
// makes the same V source drive both iOS and Android. Each `get_by_*`
// dispatches on `s.platform` and compiles down to the right per-platform
// strategy (XCUITest predicate / class chain on iOS, UiAutomator
// UiSelector / xpath on Android), returning the same lazy, auto-waiting
// MobileLocator the platform-specific factories return.
//
// The single-platform factories still exist (`accessibility_id`,
// `predicate`, `resource_id`, `text`, …) for when you need to reach for a
// strategy directly; these are the portable layer on top.

// MobileRole is the cross-platform widget role used by `get_by_role`. Each
// value maps to an XCUIElementType on iOS and an android.widget class on
// Android. Kept deliberately small — the roles that map cleanly on both
// platforms.
pub enum MobileRole {
	button
	text_field
	static_text
	image
	checkbox
	toggle // iOS Switch / Android Switch
	link
}

// role_ios_type maps a MobileRole onto its XCUITest element type.
fn role_ios_type(r MobileRole) string {
	return match r {
		.button { 'XCUIElementTypeButton' }
		.text_field { 'XCUIElementTypeTextField' }
		.static_text { 'XCUIElementTypeStaticText' }
		.image { 'XCUIElementTypeImage' }
		.checkbox { 'XCUIElementTypeCheckBox' }
		.toggle { 'XCUIElementTypeSwitch' }
		.link { 'XCUIElementTypeLink' }
	}
}

// role_android_class maps a MobileRole onto its android.widget class.
fn role_android_class(r MobileRole) string {
	return match r {
		.button { 'android.widget.Button' }
		.text_field { 'android.widget.EditText' }
		.static_text { 'android.widget.TextView' }
		.image { 'android.widget.ImageView' }
		.checkbox { 'android.widget.CheckBox' }
		.toggle { 'android.widget.Switch' }
		.link { 'android.widget.TextView' }
	}
}

// get_by_test_id locates an element by the test hook your app wires into
// its views — the most stable selector. On both platforms this is the
// accessibility identifier: XCUITest `name` on iOS, `content-desc` on
// Android, both reachable via the W3C `accessibility id` strategy.
pub fn (s &MobileSession) get_by_test_id(id string) MobileLocator {
	return s.accessibility_id(id)
}

// get_by_label locates an element by its accessible label.
//
// - iOS: predicate `label == 'X' OR name == 'X' OR value == 'X'` —
//   XCUITest spreads the accessible name across those three attributes
//   depending on the control.
// - Android: xpath `//*[@content-desc='X' or @text='X']` — prefer the
//   content description, fall back to visible text. xpath gives a true OR
//   that UiSelector can't express.
pub fn (s &MobileSession) get_by_label(text string) MobileLocator {
	return match s.platform {
		.ios {
			esc := escape_predicate(text)
			s.predicate("label == '${esc}' OR name == '${esc}' OR value == '${esc}'")
		}
		.android {
			lit := xpath_lit(text)
			s.xpath('//*[@content-desc=${lit} or @text=${lit}]')
		}
	}
}

// get_by_text locates an element by a substring of its visible text —
// the mobile analog of the web `get_by_text` (substring by default).
//
// - iOS: predicate `label CONTAINS 'X' OR name CONTAINS 'X' OR value CONTAINS 'X'`.
// - Android: UiSelector `textContains("X")`.
pub fn (s &MobileSession) get_by_text(text string) MobileLocator {
	return match s.platform {
		.ios {
			esc := escape_predicate(text)
			s.predicate("label CONTAINS '${esc}' OR name CONTAINS '${esc}' OR value CONTAINS '${esc}'")
		}
		.android {
			s.text_contains(text)
		}
	}
}

// get_by_role locates an element by widget role, optionally filtered by
// accessible name. Pass an empty `name` to match by role alone.
//
// - iOS: class chain `**/XCUIElementType…`, optionally with a
//   `[`label == 'X' OR name == 'X' OR value == 'X'`]` predicate filter.
// - Android: UiSelector `className("android.widget.…")`, optionally
//   `.text("X")`.
pub fn (s &MobileSession) get_by_role(role MobileRole, name string) MobileLocator {
	return match s.platform {
		.ios {
			ios_type := role_ios_type(role)
			if name == '' {
				s.class_chain('**/${ios_type}')
			} else {
				esc := escape_predicate(name)
				s.class_chain('**/${ios_type}[`label == \'${esc}\' OR name == \'${esc}\' OR value == \'${esc}\'`]')
			}
		}
		.android {
			cls := role_android_class(role)
			if name == '' {
				s.class_name(cls)
			} else {
				esc := escape_uiselector(name)
				s.uia2_selector('new UiSelector().className("${cls}").text("${esc}")')
			}
		}
	}
}

// locator is the generic escape hatch — build a MobileLocator from a raw
// (strategy, value) pair when none of the semantic helpers fit. `strategy`
// is the backend's wire vocabulary (`accessibility id`, `predicate string`,
// `class chain`, `id`, `class name`, `-android uiautomator`, `xpath`).
pub fn (s &MobileSession) locator(strategy string, value string) MobileLocator {
	return MobileLocator{
		session: s
		using:   strategy
		value:   value
	}
}

// xpath_lit safely quotes an arbitrary string as an xpath literal, falling
// back to concat() when the value contains both quote characters.
fn xpath_lit(s string) string {
	if !s.contains('"') {
		return '"${s}"'
	}
	if !s.contains("'") {
		return "'${s}'"
	}
	// Contains both ' and " : build concat("a", '"', "b", …)
	parts := s.split('"')
	mut pieces := []string{}
	for i, p in parts {
		pieces << '"${p}"'
		if i < parts.len - 1 {
			pieces << '\'"\''
		}
	}
	return 'concat(${pieces.join(', ')})'
}
