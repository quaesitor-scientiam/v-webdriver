module webdriver

import x.json2 as json

// Offline tests for the codegen action model, emitters, and recorder message
// parsing. No browser/device required. Raw strings (r'...'/r"...") are used for
// inputs/expectations containing $, ', \, or unicode escapes so the test source
// itself doesn't trip V's interpolation/escaping.

fn test_v_str_lit_plain() {
	assert v_str_lit('plain') == "'plain'"
}

fn test_v_str_lit_escapes_dollar() {
	assert v_str_lit(r'a$b') == r"'a\$b'"
}

fn test_v_str_lit_escapes_quote() {
	assert v_str_lit(r"it's") == r"'it\'s'"
}

fn test_v_str_lit_escapes_backslash() {
	assert v_str_lit(r'a\b') == r"'a\\b'"
}

fn test_web_locator_expr_each_kind() {
	assert web_locator_expr(LocatorSpec{ kind: .test_id, value: 'toast' }) == "b.wd.get_by_test_id('toast')"
	assert web_locator_expr(LocatorSpec{ kind: .role, role: 'button', value: 'Save' }) == "b.wd.get_by_role('button', 'Save')"
	assert web_locator_expr(LocatorSpec{ kind: .label, value: 'Email' }) == "b.wd.get_by_label('Email')"
	assert web_locator_expr(LocatorSpec{ kind: .placeholder, value: 'Search' }) == "b.wd.get_by_placeholder('Search')"
	assert web_locator_expr(LocatorSpec{ kind: .text, value: 'Next' }) == "b.wd.get_by_text('Next')"
	assert web_locator_expr(LocatorSpec{ kind: .css, value: '.btn' }) == "b.wd.locator('css=.btn')"
	assert web_locator_expr(LocatorSpec{ kind: .xpath, value: '//a' }) == "b.wd.locator('xpath=//a')"
}

fn test_web_locator_expr_nth() {
	e := web_locator_expr(LocatorSpec{ kind: .css, value: '.btn', nth: 2 })
	assert e == "b.wd.locator('css=.btn').nth(2)"
}

fn test_emit_v_web_shape() {
	acts := [
		RecordedAction{
			kind:  .goto
			value: 'https://example.com'
		},
		RecordedAction{
			kind:   .click
			target: LocatorSpec{
				kind:  .role
				role:  'button'
				value: 'Save'
			}
		},
		RecordedAction{
			kind:   .fill
			target: LocatorSpec{
				kind:  .label
				value: 'Email'
			}
			value:  'a@b.com'
		},
		RecordedAction{
			kind:   .assert_visible
			target: LocatorSpec{
				kind:  .test_id
				value: 'toast'
			}
		},
		RecordedAction{
			kind:   .assert_text
			target: LocatorSpec{
				kind:  .text
				value: 'Done'
			}
			value:  'Saved'
		},
	]
	out := emit_v_web(acts)
	assert out.contains('module main')
	assert out.contains('import vebidor.webdriver')
	assert out.contains('webdriver.launch_edge(webdriver.LaunchOptions{ headless: false })!')
	assert out.contains("b.goto('https://example.com')!")
	assert out.contains("b.wd.get_by_role('button', 'Save').click()!")
	assert out.contains("b.wd.get_by_label('Email').fill('a@b.com')!")
	assert out.contains("webdriver.expect(b.wd.get_by_test_id('toast')).to_be_visible()!")
	assert out.contains("webdriver.expect(b.wd.get_by_text('Done')).to_have_text('Saved')!")
	assert out.ends_with('}\n')
}

fn test_emit_v_web_select_and_press() {
	acts := [
		RecordedAction{
			kind:   .select_option
			target: LocatorSpec{
				kind:  .label
				value: 'Country'
			}
			value:  'Canada'
		},
		RecordedAction{
			kind:   .press
			target: LocatorSpec{
				kind:  .label
				value: 'Search'
			}
			value:  'Enter'
		},
		RecordedAction{
			kind:   .check
			target: LocatorSpec{
				kind:  .role
				role:  'checkbox'
				value: 'Agree'
			}
		},
	]
	out := emit_v_web(acts)
	assert out.contains('b.wd.get_by_label(\'Country\').locator(\'xpath=.//option[normalize-space(.)="Canada"]\').click()!')
	// Enter compiles to the W3C key escape, built without typing it literally.
	assert out.contains("b.wd.get_by_label('Search').type_text('" + r'\u' + "e007')!")
	assert out.contains("b.wd.get_by_role('checkbox', 'Agree').click()!")
}

fn test_emit_v_mobile_shape() {
	acts := [
		RecordedAction{
			kind:  .goto
			value: 'ignored'
		},
		RecordedAction{
			kind:   .click
			target: LocatorSpec{
				kind:  .role
				role:  'button'
				value: 'OK'
			}
		},
		RecordedAction{
			kind:   .fill
			target: LocatorSpec{
				kind:  .test_id
				value: 'user'
			}
			value:  'bob'
		},
		RecordedAction{
			kind:   .assert_visible
			target: LocatorSpec{
				kind:  .text
				value: 'Welcome'
			}
		},
	]
	out := emit_v_mobile(acts, 'android')
	assert out.contains('import vebidor.mobile')
	assert out.contains('mobile.launch_android(mobile.AndroidOptions{ mode: .attach })!')
	assert out.contains('// (skipped on mobile: navigation)')
	assert out.contains("s.get_by_role(.button, 'OK').tap()!")
	assert out.contains("s.get_by_test_id('user').fill('bob')!")
	assert out.contains("mobile.expect(s.get_by_text('Welcome')).to_be_visible()!")
}

fn test_emit_v_mobile_ios_launch() {
	out := emit_v_mobile([
		RecordedAction{
			kind:   .click
			target: LocatorSpec{
				kind:  .label
				value: 'Done'
			}
		},
	], 'ios')
	assert out.contains('mobile.launch_ios(mobile.IOSOptions{ mode: .attach })!')
	assert out.contains("s.get_by_label('Done').tap()!")
}

fn test_emit_v_mobile_role_fallback() {
	out := emit_v_mobile([
		RecordedAction{
			kind:   .click
			target: LocatorSpec{
				kind:  .role
				role:  'heading'
				value: 'Title'
			}
		},
	], 'android')
	assert out.contains("s.get_by_text('Title').tap()!")
}

fn test_locator_for_matches_direct_calls() {
	wd := &WebDriver{}

	a := wd.locator_for(LocatorSpec{ kind: .test_id, value: 'toast' })
	b := wd.get_by_test_id('toast')
	assert a.using == b.using
	assert a.value == b.value

	c := wd.locator_for(LocatorSpec{ kind: .role, role: 'button', value: 'Save' })
	d := wd.get_by_role('button', 'Save')
	assert c.using == d.using
	assert c.value == d.value

	e := wd.locator_for(LocatorSpec{ kind: .label, value: 'Email' })
	f := wd.get_by_label('Email')
	assert e.using == f.using
	assert e.value == f.value

	g := wd.locator_for(LocatorSpec{ kind: .placeholder, value: 'Search' })
	h := wd.get_by_placeholder('Search')
	assert g.using == h.using
	assert g.value == h.value

	i := wd.locator_for(LocatorSpec{ kind: .text, value: 'Next' })
	j := wd.get_by_text('Next')
	assert i.using == j.using
	assert i.value == j.value

	k := wd.locator_for(LocatorSpec{ kind: .css, value: '.btn' })
	assert k.using == 'css selector'
	assert k.value == '.btn'

	l := wd.locator_for(LocatorSpec{ kind: .xpath, value: '//a' })
	assert l.using == 'xpath'
	assert l.value == '//a'
}

fn test_locator_for_nth() {
	wd := &WebDriver{}
	l := wd.locator_for(LocatorSpec{ kind: .css, value: '.btn', nth: 2 })
	assert l.index == 2
}

fn test_locator_health_unique_match() {
	assert locator_health(1, -1) == ''
}

fn test_locator_health_not_found() {
	assert locator_health(0, -1) == 'not found: 0 matches (need 1)'
}

fn test_locator_health_ambiguous() {
	assert locator_health(3, -1) == 'ambiguous: 3 matches (was unique at record time)'
}

fn test_locator_health_nth_in_range() {
	assert locator_health(3, 2) == ''
}

fn test_locator_health_nth_out_of_range() {
	assert locator_health(2, 2) == 'not found: 2 matches (need 3)'
}

fn test_actions_json_round_trip() {
	acts := [
		RecordedAction{
			kind:  .goto
			value: 'https://example.com'
		},
		RecordedAction{
			kind:   .click
			target: LocatorSpec{
				kind:  .role
				role:  'button'
				value: 'Save'
			}
		},
		RecordedAction{
			kind:   .fill
			target: LocatorSpec{
				kind:  .label
				value: 'Email'
			}
			value:  'a@b.com'
		},
		RecordedAction{
			kind:   .press
			target: LocatorSpec{
				kind:  .placeholder
				value: 'Search'
			}
			value:  'Enter'
		},
		RecordedAction{
			kind:   .check
			target: LocatorSpec{
				kind:  .role
				role:  'checkbox'
				value: 'Agree'
			}
		},
		RecordedAction{
			kind:   .select_option
			target: LocatorSpec{
				kind:  .label
				value: 'Country'
			}
			value:  'Canada'
		},
		RecordedAction{
			kind:   .assert_visible
			target: LocatorSpec{
				kind:  .test_id
				value: 'toast'
			}
		},
		RecordedAction{
			kind:   .assert_text
			target: LocatorSpec{
				kind:  .text
				value: 'Done'
			}
			value:  'Saved'
		},
		RecordedAction{
			kind:   .assert_contain_text
			target: LocatorSpec{
				kind:  .css
				value: '.msg'
			}
			value:  'partial'
		},
		RecordedAction{
			kind:   .click
			target: LocatorSpec{
				kind:  .xpath
				value: '//a'
				nth:   2
			}
		},
	]
	json_str := actions_to_json(acts)
	decoded := actions_from_json(json_str) or { panic(err) }
	assert decoded.len == acts.len
	for idx, a in acts {
		d := decoded[idx]
		assert d.kind == a.kind
		assert d.value == a.value
		assert d.target.kind == a.target.kind
		assert d.target.value == a.target.value
		assert d.target.role == a.target.role
		assert d.target.nth == a.target.nth
	}
}

fn test_actions_json_empty_role_and_default_nth() {
	acts := [
		RecordedAction{
			kind:   .click
			target: LocatorSpec{
				kind:  .text
				value: 'Go'
			}
		},
	]
	decoded := actions_from_json(actions_to_json(acts)) or { panic(err) }
	assert decoded[0].target.role == ''
	assert decoded[0].target.nth == -1
}

fn test_parse_recorded_click() {
	obj := json.decode[json.Any]('{"action":"click","sel":{"kind":"role","value":"Save","role":"button","nth":-1},"value":""}') or {
		panic(err)
	}
	a := parse_recorded(obj) or { panic('parse failed') }
	assert a.kind == .click
	assert a.target.kind == .role
	assert a.target.role == 'button'
	assert a.target.value == 'Save'
}

fn test_parse_recorded_fill_and_unknown() {
	obj := json.decode[json.Any]('{"action":"fill","sel":{"kind":"test_id","value":"user","role":"","nth":-1},"value":"bob"}') or {
		panic(err)
	}
	a := parse_recorded(obj) or { panic('parse failed') }
	assert a.kind == .fill
	assert a.target.kind == .test_id
	assert a.value == 'bob'

	// Unknown action kinds are dropped (returns none).
	bad := json.decode[json.Any]('{"action":"frobnicate","sel":{},"value":""}') or { panic(err) }
	if _ := parse_recorded(bad) {
		assert false, 'expected none for unknown action'
	}
}
