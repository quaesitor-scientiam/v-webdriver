module webdriver

// Codegen — a capture-agnostic action model plus emitters that turn a recorded
// session into runnable vebidor source.
//
// The capture front-ends (web via BiDi preload script, mobile via accessibility
// hit-test) record user interactions as a `[]RecordedAction`, each carrying a
// `LocatorSpec` describing *which* semantic selector to use rather than a raw
// path. The emitters here render that list as a compilable V program whose
// locators go through the existing `get_by_*` engines — so the output is the
// same refactor-resistant shape a human would hand-write, not a brittle CSS
// chain. emit_v_web targets `webdriver` selectors; emit_v_mobile targets the
// `mobile` module's cross-platform selectors.

// SelectorKind is which semantic engine a LocatorSpec targets. These line up
// 1:1 with the get_by_* engines in selectors.v (web) and mobile/selectors.v.
pub enum SelectorKind {
	test_id     // get_by_test_id
	role        // get_by_role(role, name)
	label       // get_by_label
	placeholder // get_by_placeholder (web only; falls back to label on mobile)
	text        // get_by_text
	css         // raw css= fallback (web)
	xpath       // raw xpath= fallback
}

// LocatorSpec describes how to re-find a recorded element semantically.
pub struct LocatorSpec {
pub:
	kind  SelectorKind
	value string // id / accessible-name / placeholder / text / raw selector body
	role  string // ARIA (web) or widget (mobile) role; only when kind == .role
	nth   int = -1 // -1 = no index; >=0 emits .nth(i) on web (mobile resolves via xpath)
}

// ActionKind is the kind of interaction recorded.
pub enum ActionKind {
	goto                // navigate (web only)
	click               // click / tap
	fill                // clear + type text into a field
	press               // send a key (value holds the W3C key, e.g. '' = Enter)
	check               // toggle a checkbox/switch (emitted as a click/tap)
	select_option       // choose an <option> by visible text (web)
	assert_visible      // expect(loc).to_be_visible()
	assert_text         // expect(loc).to_have_text(value)
	assert_contain_text // expect(loc).to_contain_text(value)
}

// RecordedAction is one step in a recorded session.
pub struct RecordedAction {
pub:
	kind   ActionKind
	target LocatorSpec // unused for .goto
	value  string      // url (goto); text/key (fill/press/select/assert_text)
}

// v_str_lit renders `s` as a V single-quoted string literal, escaping the
// characters V treats specially inside one — backslash, the quote, `$` (string
// interpolation), and the usual control characters. Used so recorded values
// with quotes/newlines/`$` survive into the generated source intact.
fn v_str_lit(s string) string {
	mut b := []u8{cap: s.len + 2}
	b << `'`
	for c in s {
		match c {
			`\\` {
				b << `\\`
				b << `\\`
			}
			`'` {
				b << `\\`
				b << `'`
			}
			`$` {
				b << `\\`
				b << `$`
			}
			`\n` {
				b << `\\`
				b << `n`
			}
			`\r` {
				b << `\\`
				b << `r`
			}
			`\t` {
				b << `\\`
				b << `t`
			}
			else {
				b << c
			}
		}
	}
	b << `'`
	return b.bytestr()
}

// --- web emitter -----------------------------------------------------------

// web_locator_expr renders a LocatorSpec as a `webdriver` Locator expression
// rooted on the launched Browser `b`.
fn web_locator_expr(spec LocatorSpec) string {
	base := match spec.kind {
		.test_id { 'b.wd.get_by_test_id(${v_str_lit(spec.value)})' }
		.role { 'b.wd.get_by_role(${v_str_lit(spec.role)}, ${v_str_lit(spec.value)})' }
		.label { 'b.wd.get_by_label(${v_str_lit(spec.value)})' }
		.placeholder { 'b.wd.get_by_placeholder(${v_str_lit(spec.value)})' }
		.text { 'b.wd.get_by_text(${v_str_lit(spec.value)})' }
		.css { 'b.wd.locator(${v_str_lit('css=' + spec.value)})' }
		.xpath { 'b.wd.locator(${v_str_lit('xpath=' + spec.value)})' }
	}

	if spec.nth >= 0 {
		return '${base}.nth(${spec.nth})'
	}
	return base
}

// press_key_literal renders a recorded key name as the V string literal a
// caller would type — mapping the common keys to their W3C key codes so the
// generated source reads `''` (Enter) rather than an opaque character.
fn press_key_literal(name string) string {
	code := match name {
		'Enter' { 0xe007 }
		'Tab' { 0xe004 }
		'Escape' { 0xe00c }
		else { 0 }
	}

	if code == 0 {
		return v_str_lit(name)
	}
	// Build a readable V escape (e.g. '') for the W3C key char without
	// embedding a control character in the source.
	return "'" + r'\u' + code.hex() + "'"
}

// web_action_line renders one RecordedAction as a line of V source.
fn web_action_line(a RecordedAction) string {
	if a.kind == .goto {
		return '\tb.goto(${v_str_lit(a.value)})!'
	}
	loc := web_locator_expr(a.target)
	return match a.kind {
		.goto {
			''
		} // handled above
		.click {
			'\t${loc}.click()!'
		}
		.fill {
			'\t${loc}.fill(${v_str_lit(a.value)})!'
		}
		.press {
			'\t${loc}.type_text(${press_key_literal(a.value)})!'
		}
		.check {
			'\t${loc}.click()!'
		}
		.select_option {
			xp := 'xpath=.//option[normalize-space(.)=${xpath_literal(a.value)}]'
			'\t${loc}.locator(${v_str_lit(xp)}).click()!'
		}
		.assert_visible {
			'\twebdriver.expect(${loc}).to_be_visible()!'
		}
		.assert_text {
			'\twebdriver.expect(${loc}).to_have_text(${v_str_lit(a.value)})!'
		}
		.assert_contain_text {
			'\twebdriver.expect(${loc}).to_contain_text(${v_str_lit(a.value)})!'
		}
	}
}

// emit_v_web renders a recorded web session as a runnable V program using the
// Playwright-style launch + Locator + expect API.
pub fn emit_v_web(actions []RecordedAction) string {
	mut lines := [
		'module main',
		'',
		'import vebidor.webdriver',
		'',
		'// Generated by `vebidor codegen`. Review before committing - generated',
		'// selectors are a starting point, not a substitute for judgement.',
		'fn main() {',
		'\tmut b := webdriver.launch_edge(webdriver.LaunchOptions{ headless: false })!',
		'\tdefer { b.close() }',
		'',
	]
	for a in actions {
		lines << web_action_line(a)
	}
	lines << '}'
	return lines.join('\n') + '\n'
}

// --- mobile emitter --------------------------------------------------------

// mobile_role_expr maps a role string onto a `mobile.MobileRole` enum literal,
// or '' if it has no clean cross-platform mapping (caller falls back to text).
fn mobile_role_expr(role string) string {
	return match role {
		'button' { '.button' }
		'textbox', 'text_field', 'textfield' { '.text_field' }
		'static_text', 'text' { '.static_text' }
		'img', 'image' { '.image' }
		'checkbox' { '.checkbox' }
		'toggle', 'switch' { '.toggle' }
		'link' { '.link' }
		else { '' }
	}
}

// mobile_locator_expr renders a LocatorSpec as a `mobile` MobileLocator
// expression on the session `s`. Mobile has no nth(); the capture side resolves
// uniqueness by emitting an xpath spec instead.
fn mobile_locator_expr(spec LocatorSpec) string {
	return match spec.kind {
		.test_id {
			's.get_by_test_id(${v_str_lit(spec.value)})'
		}
		.label, .placeholder {
			's.get_by_label(${v_str_lit(spec.value)})'
		}
		.text {
			's.get_by_text(${v_str_lit(spec.value)})'
		}
		.css, .xpath {
			's.xpath(${v_str_lit(spec.value)})'
		}
		.role {
			r := mobile_role_expr(spec.role)
			if r == '' {
				// no clean role mapping — fall back to the accessible name
				's.get_by_text(${v_str_lit(spec.value)})'
			} else {
				's.get_by_role(${r}, ${v_str_lit(spec.value)})'
			}
		}
	}
}

// mobile_action_line renders one RecordedAction as a line of mobile V source.
// goto/select_option/press have no mobile equivalent and are emitted as a
// comment so a reviewer can see what was dropped.
fn mobile_action_line(a RecordedAction) string {
	if a.kind == .goto {
		return '\t// (skipped on mobile: navigation)'
	}
	if a.kind == .select_option {
		return '\t// (skipped on mobile: select_option)'
	}
	if a.kind == .press {
		return '\t// (skipped on mobile: key press)'
	}
	loc := mobile_locator_expr(a.target)
	return match a.kind {
		.click, .check { '\t${loc}.tap()!' }
		.fill { '\t${loc}.fill(${v_str_lit(a.value)})!' }
		.assert_visible { '\tmobile.expect(${loc}).to_be_visible()!' }
		.assert_text { '\tmobile.expect(${loc}).to_have_text(${v_str_lit(a.value)})!' }
		.assert_contain_text { '\tmobile.expect(${loc}).to_contain_text(${v_str_lit(a.value)})!' }
		else { '' }
	}
}

// emit_v_mobile renders a recorded mobile session as a runnable V program. The
// launch scaffold is left as a TODO because device coordinates (udid, APK
// paths, bundle id) are environment-specific and can't be inferred from the
// captured actions.
pub fn emit_v_mobile(actions []RecordedAction, platform string) string {
	launch_line := if platform == 'ios' {
		'\tmut s := mobile.launch_ios(mobile.IOSOptions{ mode: .attach })! // TODO: set udid/bundle_id'
	} else {
		'\tmut s := mobile.launch_android(mobile.AndroidOptions{ mode: .attach })! // TODO: set udid/app_package'
	}
	mut lines := [
		'module main',
		'',
		'import vebidor.mobile',
		'',
		'// Generated by `vebidor codegen`. Review before committing - fill in the',
		'// launch options for your device/emulator.',
		'fn main() {',
		launch_line,
		'\tdefer { s.close() }',
		'',
	]
	for a in actions {
		lines << mobile_action_line(a)
	}
	lines << '}'
	return lines.join('\n') + '\n'
}
