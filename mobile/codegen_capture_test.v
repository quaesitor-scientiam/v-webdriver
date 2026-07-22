module mobile

import vebidor.webdriver

// Offline tests for the mobile capture core — no device required. Cover the
// coordinate scaling, the getevent stream parser, the wm/getevent text
// parsers, the XML node parser + hit-test, and the per-platform selector
// synthesis priority.

fn test_scale_point_typical() {
	// 0..32767 raw range mapped onto a 1080x2400 screen.
	x, y := scale_point(16383, 16383, 32767, 32767, 1080, 2400)
	assert x == 539
	assert y == 1199
}

fn test_scale_point_passthrough_when_no_max() {
	// A touchscreen already reporting pixels (max <= 0) passes through.
	x, y := scale_point(640, 1280, 0, 0, 1080, 2400)
	assert x == 640
	assert y == 1280
}

fn test_parse_screen_size() {
	w, h := parse_screen_size('Physical size: 1080x2400\n')
	assert w == 1080
	assert h == 2400
}

fn test_parse_screen_size_override_wins() {
	out := 'Physical size: 1080x2400\nOverride size: 720x1600\n'
	w, h := parse_screen_size(out)
	assert w == 720
	assert h == 1600
}

fn test_parse_touch_max() {
	out := '  ABS_MT_POSITION_X    : value 0, min 0, max 1079, fuzz 0, flat 0\n' +
		'  ABS_MT_POSITION_Y    : value 0, min 0, max 2399, fuzz 0, flat 0\n'
	mx, my := parse_touch_max(out)
	assert mx == 1079
	assert my == 2399
}

fn test_getevent_parser_emits_tap_on_tracking_id_release() {
	mut p := GetEventParser{}
	lines := [
		'[ 1234.5] /dev/input/event4: EV_ABS ABS_MT_TRACKING_ID 0000001f',
		'[ 1234.5] /dev/input/event4: EV_ABS ABS_MT_POSITION_X 000003e8', // 1000
		'[ 1234.5] /dev/input/event4: EV_ABS ABS_MT_POSITION_Y 000007d0', // 2000
		'[ 1234.5] /dev/input/event4: EV_SYN SYN_REPORT 00000000',
	]
	for l in lines {
		assert p.feed(l) == none
	}
	tap := p.feed('[ 1234.6] /dev/input/event4: EV_ABS ABS_MT_TRACKING_ID ffffffff') or {
		assert false, 'expected a tap on finger-up'
		return
	}
	assert tap.x == 1000
	assert tap.y == 2000
}

fn test_getevent_parser_btn_touch_up() {
	mut p := GetEventParser{}
	p.feed('EV_ABS ABS_MT_POSITION_X 00000064') or {} // 100
	p.feed('EV_ABS ABS_MT_POSITION_Y 000000c8') or {} // 200
	tap := p.feed('EV_KEY BTN_TOUCH UP') or {
		assert false, 'expected a tap on BTN_TOUCH UP'
		return
	}
	assert tap.x == 100
	assert tap.y == 200
}

fn test_parse_bounds() {
	r := parse_bounds('[10,20][110,140]') or {
		assert false, 'bounds should parse'
		return
	}
	assert r.x == 10
	assert r.y == 20
	assert r.w == 100
	assert r.h == 120
}

fn test_xml_unescape() {
	assert xml_unescape('&lt;a&gt; &amp; &quot;x&quot; &apos;y&apos;') == '<a> & "x" \'y\''
	assert xml_unescape('plain') == 'plain'
}

const android_xml = '<hierarchy rotation="0">
  <android.widget.FrameLayout class="android.widget.FrameLayout" bounds="[0,0][1080,2400]">
    <android.widget.Button class="android.widget.Button" content-desc="Confirm" text="OK" resource-id="com.x:id/ok" clickable="true" bounds="[40,100][200,180]"/>
    <android.widget.EditText class="android.widget.EditText" resource-id="com.x:id/email" text="" clickable="true" bounds="[40,300][1040,380]"/>
    <android.widget.TextView class="android.widget.TextView" text="Welcome back" bounds="[40,400][500,440]"/>
    <android.widget.Button class="android.widget.Button" text="" bounds="[40,500][200,560]"/>
    <android.view.View class="android.view.View" bounds="[40,700][200,760]"/>
  </android.widget.FrameLayout>
</hierarchy>'

fn test_parse_nodes_android_count() {
	nodes := parse_nodes(android_xml)
	// <hierarchy> + frame + 4 widgets + view = 7 (nodes without a rect are
	// still parsed; only the point-containing ones matter to hit_test).
	assert nodes.len == 7
}

fn test_hit_test_picks_smallest_containing() {
	nodes := parse_nodes(android_xml)
	// (100,140) is inside both the root frame and the Confirm button.
	idx := hit_test_index(nodes, 100, 140) or {
		assert false, 'expected a hit'
		return
	}
	assert nodes[idx].node_class() == 'android.widget.Button'
	assert (nodes[idx].attrs['content-desc'] or { '' }) == 'Confirm'
}

fn test_synth_android_test_id() {
	nodes := parse_nodes(android_xml)
	idx := hit_test_index(nodes, 100, 140) or {
		assert false
		return
	}
	spec := synth_locator(.android, nodes, idx)
	assert spec.kind == .test_id
	assert spec.value == 'Confirm'
}

fn test_synth_android_resource_id_xpath() {
	nodes := parse_nodes(android_xml)
	idx := hit_test_index(nodes, 100, 340) or {
		assert false
		return
	}
	spec := synth_locator(.android, nodes, idx)
	assert spec.kind == .xpath
	assert spec.value == '//*[@resource-id="com.x:id/email"]'
}

fn test_synth_android_text() {
	nodes := parse_nodes(android_xml)
	idx := hit_test_index(nodes, 100, 420) or {
		assert false
		return
	}
	spec := synth_locator(.android, nodes, idx)
	assert spec.kind == .text
	assert spec.value == 'Welcome back'
}

fn test_synth_android_role() {
	nodes := parse_nodes(android_xml)
	// The empty-text Button: no desc/rid/text, but class maps to a role.
	idx := hit_test_index(nodes, 100, 530) or {
		assert false
		return
	}
	spec := synth_locator(.android, nodes, idx)
	assert spec.kind == .role
	assert spec.role == 'button'
	assert spec.value == ''
}

fn test_synth_android_positional_fallback() {
	nodes := parse_nodes(android_xml)
	// android.view.View: no semantic attr and no role mapping -> positional.
	idx := hit_test_index(nodes, 100, 730) or {
		assert false
		return
	}
	spec := synth_locator(.android, nodes, idx)
	assert spec.kind == .xpath
	assert spec.value == '(//android.view.View)[1]'
}

const ios_xml = '<XCUIElementTypeApplication type="XCUIElementTypeApplication" name="App" x="0" y="0" width="390" height="844">
  <XCUIElementTypeButton type="XCUIElementTypeButton" name="login_btn" label="Log In" x="20" y="100" width="120" height="44"/>
  <XCUIElementTypeStaticText type="XCUIElementTypeStaticText" name="" label="Welcome" x="20" y="200" width="200" height="20"/>
  <XCUIElementTypeButton type="XCUIElementTypeButton" name="" label="" x="20" y="300" width="120" height="44"/>
</XCUIElementTypeApplication>'

fn test_synth_ios_test_id() {
	nodes := parse_nodes(ios_xml)
	idx := hit_test_index(nodes, 80, 120) or {
		assert false
		return
	}
	spec := synth_locator(.ios, nodes, idx)
	assert spec.kind == .test_id
	assert spec.value == 'login_btn'
}

fn test_synth_ios_label() {
	nodes := parse_nodes(ios_xml)
	idx := hit_test_index(nodes, 100, 205) or {
		assert false
		return
	}
	spec := synth_locator(.ios, nodes, idx)
	assert spec.kind == .label
	assert spec.value == 'Welcome'
}

fn test_synth_ios_role() {
	nodes := parse_nodes(ios_xml)
	idx := hit_test_index(nodes, 80, 320) or {
		assert false
		return
	}
	spec := synth_locator(.ios, nodes, idx)
	assert spec.kind == .role
	assert spec.role == 'button'
	assert spec.value == ''
}

fn test_is_editable() {
	edit := UiNode{
		tag:   'android.widget.EditText'
		attrs: {
			'class': 'android.widget.EditText'
		}
	}
	assert is_editable(.android, edit)
	btn := UiNode{
		tag:   'android.widget.Button'
		attrs: {
			'class': 'android.widget.Button'
		}
	}
	assert !is_editable(.android, btn)
	ios_field := UiNode{
		tag:   'XCUIElementTypeTextField'
		attrs: {
			'type': 'XCUIElementTypeTextField'
		}
	}
	assert is_editable(.ios, ios_field)
}

fn test_parse_nodes_handles_gt_in_attr() {
	// A '>' inside an attribute value must not end the tag early.
	xml := '<node text="a &gt; b" class="android.widget.TextView" bounds="[0,0][10,10]"/>'
	nodes := parse_nodes(xml)
	assert nodes.len == 1
	assert (nodes[0].attrs['text'] or { '' }) == 'a > b'
}

// --- MobileSession.locator_for: matches the direct get_by_* calls ----------
// (the spec->locator resolver used by audit mode to replay a persisted
// recording, promoted from the recorder onto the session in this change.)

fn test_locator_for_android_test_id() {
	s := &MobileSession{
		platform: .android
	}
	l := s.locator_for(webdriver.LocatorSpec{
		kind:  .test_id
		value: 'submit'
	})
	direct := s.get_by_test_id('submit')
	assert l.using == direct.using
	assert l.value == direct.value
}

fn test_locator_for_android_role() {
	s := &MobileSession{
		platform: .android
	}
	l := s.locator_for(webdriver.LocatorSpec{
		kind:  .role
		role:  'button'
		value: 'OK'
	})
	direct := s.get_by_role(.button, 'OK')
	assert l.using == direct.using
	assert l.value == direct.value
}

fn test_locator_for_role_fallback_unmapped() {
	// 'heading' has no clean MobileRole mapping, so locator_for should fall
	// back to get_by_text — mirroring the emitter's role fallback.
	s := &MobileSession{
		platform: .android
	}
	l := s.locator_for(webdriver.LocatorSpec{
		kind:  .role
		role:  'heading'
		value: 'Title'
	})
	direct := s.get_by_text('Title')
	assert l.using == direct.using
	assert l.value == direct.value
}

fn test_locator_for_ios_label() {
	s := &MobileSession{
		platform: .ios
	}
	l := s.locator_for(webdriver.LocatorSpec{
		kind:  .label
		value: 'Done'
	})
	direct := s.get_by_label('Done')
	assert l.using == direct.using
	assert l.value == direct.value
}

fn test_locator_for_xpath() {
	s := &MobileSession{
		platform: .android
	}
	l := s.locator_for(webdriver.LocatorSpec{
		kind:  .xpath
		value: '//button'
	})
	assert l.using == 'xpath'
	assert l.value == '//button'
}
