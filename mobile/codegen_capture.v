module mobile

import os
import vebidor.webdriver

// Layer 3 — mobile capture. Turns real on-device interaction into a
// `[]webdriver.RecordedAction` that the shared `emit_v_mobile` emitter renders
// as runnable vebidor source. Two front-ends, one model:
//
//   - Android (primary, passive): stream `adb shell getevent -lt`, scale raw
//     touch coordinates to screen pixels, and on finger-up snapshot
//     `page_source()`, hit-test the topmost leaf under the point, and
//     synthesize a semantic `LocatorSpec` via the same priority as
//     mobile/selectors.v. No device cooperation needed — the user just taps.
//   - iOS (assisted, REPL): XCUITest exposes no passive touch stream, so the
//     operator names targets (`tap x y` / `text …` / `assert x y`); each is
//     hit-tested against the current source, performed, and recorded.
//
// Everything below the MobileRecorder line is pure and offline-testable
// (parsers, coordinate scaling, hit-test, selector synthesis); the recorder
// and the adb stream helpers are the thin live layer on top.

// MobileRecorder collects interactions into a RecordedAction list. It holds a
// reference to the live session (for page_source / element queries) and the
// growing action list. Created via `session.new_recorder()`.
@[heap]
pub struct MobileRecorder {
mut:
	session             &MobileSession
	actions             []webdriver.RecordedAction
	pending_edit        bool
	pending_edit_spec   webdriver.LocatorSpec
	pending_edit_before string
}

// new_recorder opens a recorder bound to this session.
pub fn (s &MobileSession) new_recorder() &MobileRecorder {
	return &MobileRecorder{
		session: s
	}
}

// actions returns the recorded actions so far.
pub fn (r &MobileRecorder) actions() []webdriver.RecordedAction {
	return r.actions
}

// emit renders the recorded session as a runnable V program via the shared
// mobile emitter, targeting the session's platform.
pub fn (r &MobileRecorder) emit() string {
	plat := if r.session.platform == .ios { 'ios' } else { 'android' }
	return webdriver.emit_v_mobile(r.actions, plat)
}

// record_tap_at snapshots the current UI tree, hit-tests the element under
// (x, y), synthesizes a semantic locator, and records it. It does NOT perform
// the tap — on Android the user already tapped the physical screen; the iOS
// REPL performs the tap itself after recording. A tap that lands on an
// editable field is deferred (see flush_pending_edit) so the eventual text is
// captured as a single `fill`.
pub fn (mut r MobileRecorder) record_tap_at(x int, y int) ! {
	r.flush_pending_edit()!
	nodes := r.snapshot_nodes()!
	idx := hit_test_index(nodes, x, y) or { return error('no UI element found at (${x}, ${y})') }
	node := nodes[idx]
	spec := synth_locator(r.session.platform, nodes, idx)
	if is_editable(r.session.platform, node) {
		r.pending_edit = true
		r.pending_edit_spec = spec
		r.pending_edit_before = current_field_text(node)
		return
	}
	r.actions << webdriver.RecordedAction{
		kind:   .click
		target: spec
	}
}

// record_assert_at records an assert_visible against the element under
// (x, y). Used by the iOS REPL's `assert` command.
pub fn (mut r MobileRecorder) record_assert_at(x int, y int) ! {
	r.flush_pending_edit()!
	nodes := r.snapshot_nodes()!
	idx := hit_test_index(nodes, x, y) or { return error('no UI element found at (${x}, ${y})') }
	spec := synth_locator(r.session.platform, nodes, idx)
	r.actions << webdriver.RecordedAction{
		kind:   .assert_visible
		target: spec
	}
}

// record_text fills the most recently tapped text field with `s`, performing
// the type and recording a `fill`. Must follow a tap that landed on an
// editable field. Used by the iOS REPL's `text` command.
pub fn (mut r MobileRecorder) record_text(s string) ! {
	if !r.pending_edit {
		return error('`text` must follow a `tap` on a text field')
	}
	spec := r.pending_edit_spec
	r.pending_edit = false
	r.locator_for(spec).fill(s)!
	r.actions << webdriver.RecordedAction{
		kind:   .fill
		target: spec
		value:  s
	}
}

// flush_pending_edit resolves a deferred edit: if the field's text changed
// since the focusing tap, record a `fill`; otherwise record the tap so the
// focus step isn't lost. Called before recording the next action and once at
// the end of a session.
pub fn (mut r MobileRecorder) flush_pending_edit() ! {
	if !r.pending_edit {
		return
	}
	r.pending_edit = false
	spec := r.pending_edit_spec
	after := r.current_text(spec) or { '' }
	if after != '' && after != r.pending_edit_before {
		r.actions << webdriver.RecordedAction{
			kind:   .fill
			target: spec
			value:  after
		}
	} else {
		r.actions << webdriver.RecordedAction{
			kind:   .click
			target: spec
		}
	}
}

// snapshot_nodes pulls the current page source and parses it into a flat node
// list in document order.
fn (r &MobileRecorder) snapshot_nodes() ![]UiNode {
	xml := r.session.page_source()!
	return parse_nodes(xml)
}

// current_text reads the live text/value of the field a spec points at, used
// to detect what the user typed.
fn (r &MobileRecorder) current_text(spec webdriver.LocatorSpec) !string {
	el := r.locator_for(spec).find()!
	attr := if r.session.platform == .android { 'text' } else { 'value' }
	return r.session.element_attribute(el, attr)
}

// locator_for rebuilds a live MobileLocator from a synthesized spec, mirroring
// the emitter's mobile_locator_expr so what we perform matches what we emit.
// Lives on MobileSession (not just the recorder) so audit mode can resolve a
// persisted spec against the live device without needing a MobileRecorder.
pub fn (s &MobileSession) locator_for(spec webdriver.LocatorSpec) MobileLocator {
	return match spec.kind {
		.test_id {
			s.get_by_test_id(spec.value)
		}
		.label, .placeholder {
			s.get_by_label(spec.value)
		}
		.text {
			s.get_by_text(spec.value)
		}
		.css, .xpath {
			s.xpath(spec.value)
		}
		.role {
			role := role_from_string(spec.role) or { return s.get_by_text(spec.value) }
			s.get_by_role(role, spec.value)
		}
	}
}

// locator_for delegates to the session so the recorder and audit mode share
// exactly one spec->locator implementation.
fn (r &MobileRecorder) locator_for(spec webdriver.LocatorSpec) MobileLocator {
	return r.session.locator_for(spec)
}

// perform_action performs one recorded step live on the device — the
// execution twin of mobile_action_line (webdriver/codegen.v), which only
// emits a string of V source for it. goto/select_option/press have no mobile
// equivalent and are silently skipped here too, exactly as the emitter drops
// them. Used by audit mode to replay a persisted recording so later steps
// see the state earlier ones produced.
pub fn (mut s MobileSession) perform_action(a webdriver.RecordedAction) ! {
	if a.kind == .goto || a.kind == .select_option || a.kind == .press {
		return
	}
	loc := s.locator_for(a.target)
	match a.kind {
		.click, .check {
			loc.tap()!
		}
		.fill {
			loc.fill(a.value)!
		}
		.assert_visible {
			expect(loc).to_be_visible()!
		}
		.assert_text {
			expect(loc).to_have_text(a.value)!
		}
		.assert_contain_text {
			expect(loc).to_contain_text(a.value)!
		}
		else {}
	}
}

// --- Android device queries + touch stream ---------------------------------

// screen_size returns the device's physical screen size in pixels, parsed from
// `adb shell wm size`. Android only.
pub fn (s MobileSession) screen_size() !(int, int) {
	out := s.adb_capture('shell wm size')!
	w, h := parse_screen_size(out)
	if w == 0 || h == 0 {
		return error('could not parse screen size from `wm size`: ${out.trim_space()}')
	}
	return w, h
}

// touch_axis_max returns the max raw value of the ABS_MT_POSITION_X/Y axes,
// parsed from `adb shell getevent -p`. These are usually NOT pixels (often
// 0..32767); scale_point converts raw touch coords to screen pixels using
// them. Android only.
pub fn (s MobileSession) touch_axis_max() !(int, int) {
	out := s.adb_capture('shell getevent -lp')!
	mx, my := parse_touch_max(out)
	return mx, my
}

// start_touch_stream spawns `adb shell getevent -lt` with stdio redirected and
// returns the process handle. The caller reads its stdout line-by-line through
// a GetEventParser and kills it to stop. Android only.
pub fn (s MobileSession) start_touch_stream() !&os.Process {
	adb := detect_adb()!
	mut p := os.new_process(adb)
	mut args := []string{}
	if s.device_udid != '' {
		args << '-s'
		args << s.device_udid
	}
	args << 'shell'
	args << 'getevent'
	args << '-lt'
	p.set_args(args)
	p.set_redirect_stdio()
	p.run()
	return p
}

// ===========================================================================
// Pure, offline-testable core: parsers, scaling, hit-test, synthesis.
// ===========================================================================

// Rect is an on-screen rectangle in device pixels.
pub struct Rect {
pub:
	x int
	y int
	w int
	h int
}

// UiNode is one element from a parsed accessibility tree: its tag (the class
// name on Android / the XCUIElementType on iOS), its attributes, and its
// screen rectangle when one could be derived.
pub struct UiNode {
pub:
	tag      string
	attrs    map[string]string
	rect     Rect
	has_rect bool
}

// TapPoint is a raw touch coordinate emitted by the getevent parser on
// finger-up, before scaling to screen pixels.
pub struct TapPoint {
pub:
	x int
	y int
}

// node_class returns the Android widget class (the `class` attr, or the tag).
fn (n UiNode) node_class() string {
	return n.attrs['class'] or { n.tag }
}

// node_type returns the iOS XCUIElementType (the `type` attr, or the tag).
fn (n UiNode) node_type() string {
	return n.attrs['type'] or { n.tag }
}

// parse_nodes scans an accessibility-tree XML string into a flat, document
// order list of UiNodes. It is a minimal quote-aware tag scanner — robust to
// `>` inside attribute values and to both the Android (class-named tags,
// `bounds`) and iOS (XCUIElementType tags, x/y/width/height) dialects.
pub fn parse_nodes(xml string) []UiNode {
	mut nodes := []UiNode{}
	mut i := 0
	for i < xml.len {
		lt := xml.index_after('<', i) or { break }
		// Skip declarations, comments, and closing tags.
		if lt + 1 < xml.len {
			c := xml[lt + 1]
			if c == `?` || c == `!` || c == `/` {
				gt := xml.index_after('>', lt) or { break }
				i = gt + 1
				continue
			}
		}
		// Find the tag's closing '>', honoring quoted attribute values.
		mut j := lt + 1
		mut quote := u8(0)
		for j < xml.len {
			ch := xml[j]
			if quote != 0 {
				if ch == quote {
					quote = 0
				}
			} else if ch == `"` || ch == `'` {
				quote = ch
			} else if ch == `>` {
				break
			}
			j++
		}
		if j >= xml.len {
			break
		}
		inner := xml[lt + 1..j]
		tag, attrs := parse_tag(inner)
		if tag != '' {
			rect, has := node_rect(attrs)
			nodes << UiNode{
				tag:      tag
				attrs:    attrs
				rect:     rect
				has_rect: has
			}
		}
		i = j + 1
	}
	return nodes
}

// parse_tag splits a tag's inner text (between '<' and '>') into the element
// name and its attribute map, quote-aware and entity-decoded.
fn parse_tag(inner_raw string) (string, map[string]string) {
	mut s := inner_raw.trim_space()
	if s.ends_with('/') {
		s = s[..s.len - 1].trim_space()
	}
	mut attrs := map[string]string{}
	// Tag name: up to first whitespace.
	mut k := 0
	for k < s.len && !s[k].is_space() {
		k++
	}
	tag := s[..k]
	mut idx := k
	for idx < s.len {
		for idx < s.len && s[idx].is_space() {
			idx++
		}
		if idx >= s.len {
			break
		}
		start := idx
		for idx < s.len && s[idx] != `=` && !s[idx].is_space() {
			idx++
		}
		key := s[start..idx]
		for idx < s.len && s[idx].is_space() {
			idx++
		}
		if idx < s.len && s[idx] == `=` {
			idx++
			for idx < s.len && s[idx].is_space() {
				idx++
			}
			if idx < s.len && (s[idx] == `"` || s[idx] == `'`) {
				q := s[idx]
				idx++
				vstart := idx
				for idx < s.len && s[idx] != q {
					idx++
				}
				val := s[vstart..idx]
				if idx < s.len {
					idx++
				}
				if key.len > 0 {
					attrs[key] = xml_unescape(val)
				}
			}
		} else if key.len == 0 {
			idx++
		}
	}
	return tag, attrs
}

// xml_unescape decodes the five predefined XML entities.
fn xml_unescape(s string) string {
	if !s.contains('&') {
		return s
	}
	return s.replace('&lt;', '<').replace('&gt;', '>').replace('&quot;', '"').replace('&apos;', "'").replace('&amp;',
		'&')
}

// node_rect derives a node's screen rectangle: Android `bounds="[x1,y1][x2,y2]"`
// first, else iOS x/y/width/height attributes.
fn node_rect(attrs map[string]string) (Rect, bool) {
	if b := attrs['bounds'] {
		if r := parse_bounds(b) {
			return r, true
		}
	}
	if xs := attrs['x'] {
		x := int(xs.f64())
		y := int((attrs['y'] or { '0' }).f64())
		w := int((attrs['width'] or { '0' }).f64())
		h := int((attrs['height'] or { '0' }).f64())
		return Rect{x, y, w, h}, true
	}
	return Rect{}, false
}

// parse_bounds parses an Android bounds string `[x1,y1][x2,y2]` into a Rect.
fn parse_bounds(s string) ?Rect {
	a := s.index(']') or { return none }
	first := s[1..a] // x1,y1
	rest := s[a + 1..]
	b := rest.index(']') or { return none }
	second := rest[1..b] // x2,y2
	fp := first.split(',')
	sp := second.split(',')
	if fp.len < 2 || sp.len < 2 {
		return none
	}
	x1 := fp[0].trim_space().int()
	y1 := fp[1].trim_space().int()
	x2 := sp[0].trim_space().int()
	y2 := sp[1].trim_space().int()
	return Rect{
		x: x1
		y: y1
		w: x2 - x1
		h: y2 - y1
	}
}

// hit_test_index returns the index of the smallest-area node whose rectangle
// contains (x, y) — the topmost leaf under the touch. Ties break toward a
// `clickable="true"` node. Returns none when nothing contains the point.
pub fn hit_test_index(nodes []UiNode, x int, y int) ?int {
	mut best := -1
	mut best_area := i64(0)
	mut best_clickable := false
	for i, n in nodes {
		if !n.has_rect {
			continue
		}
		r := n.rect
		if r.w <= 0 || r.h <= 0 {
			continue
		}
		if x < r.x || x >= r.x + r.w || y < r.y || y >= r.y + r.h {
			continue
		}
		area := i64(r.w) * i64(r.h)
		clickable := (n.attrs['clickable'] or { '' }) == 'true'
		if best == -1 || area < best_area || (area == best_area && clickable && !best_clickable) {
			best = i
			best_area = area
			best_clickable = clickable
		}
	}
	if best == -1 {
		return none
	}
	return best
}

// scale_point converts a raw touch coordinate to screen pixels using the
// axis maxima from `getevent -p`. When max <= 0 (the touch device already
// reports pixels) the coordinate passes through unchanged.
pub fn scale_point(raw_x int, raw_y int, max_x int, max_y int, screen_w int, screen_h int) (int, int) {
	sx := if max_x > 0 { int(i64(raw_x) * i64(screen_w) / i64(max_x + 1)) } else { raw_x }
	sy := if max_y > 0 { int(i64(raw_y) * i64(screen_h) / i64(max_y + 1)) } else { raw_y }
	return sx, sy
}

// parse_screen_size extracts width/height from `adb shell wm size`
// ("Physical size: 1080x2400"). An Override line, if present, wins because it
// reflects the active resolution.
pub fn parse_screen_size(out string) (int, int) {
	mut w := 0
	mut h := 0
	for line in out.split_into_lines() {
		l := line.trim_space()
		if l.starts_with('Physical size:') || l.starts_with('Override size:') {
			val := l.all_after(':').trim_space()
			parts := val.split('x')
			if parts.len == 2 {
				pw := parts[0].trim_space().int()
				ph := parts[1].trim_space().int()
				if l.starts_with('Override size:') {
					return pw, ph
				}
				w = pw
				h = ph
			}
		}
	}
	return w, h
}

// parse_touch_max scans `getevent -p` output for the ABS_MT_POSITION_X/Y axes
// and returns each axis's `max`. Zero when an axis wasn't found.
pub fn parse_touch_max(out string) (int, int) {
	mut mx := 0
	mut my := 0
	for line in out.split_into_lines() {
		if line.contains('ABS_MT_POSITION_X') {
			mx = max_field(line)
		} else if line.contains('ABS_MT_POSITION_Y') {
			my = max_field(line)
		}
	}
	return mx, my
}

// max_field reads the integer following "max " on a getevent -p axis line.
fn max_field(line string) int {
	idx := line.index('max ') or { return 0 }
	rest := line[idx + 4..]
	mut end := 0
	for end < rest.len && (rest[end].is_digit() || rest[end] == `-`) {
		end++
	}
	if end == 0 {
		return 0
	}
	return rest[..end].int()
}

// GetEventParser is a streaming state machine over `getevent -lt` lines. Feed
// it one line at a time; it returns a TapPoint on finger-up (raw, unscaled).
pub struct GetEventParser {
pub mut:
	have_x bool
	have_y bool
	last_x int
	last_y int
}

// feed advances the parser by one getevent line, returning a raw TapPoint when
// the line completes a touch (finger-up via ABS_MT_TRACKING_ID ffffffff or
// BTN_TOUCH UP).
pub fn (mut p GetEventParser) feed(line string) ?TapPoint {
	if line.contains('ABS_MT_POSITION_X') {
		p.last_x = hex_token(line)
		p.have_x = true
		return none
	}
	if line.contains('ABS_MT_POSITION_Y') {
		p.last_y = hex_token(line)
		p.have_y = true
		return none
	}
	if line.contains('ABS_MT_TRACKING_ID') {
		if last_token(line) == 'ffffffff' {
			return p.release()
		}
		return none
	}
	if line.contains('BTN_TOUCH') {
		if last_token(line).to_upper() == 'UP' {
			return p.release()
		}
		return none
	}
	return none
}

// release emits the buffered coordinate as a tap if both axes were seen, then
// clears the per-touch state.
fn (mut p GetEventParser) release() ?TapPoint {
	if p.have_x && p.have_y {
		t := TapPoint{
			x: p.last_x
			y: p.last_y
		}
		p.have_x = false
		p.have_y = false
		return t
	}
	return none
}

// last_token returns the final whitespace-separated token of a line.
fn last_token(line string) string {
	f := line.fields()
	if f.len == 0 {
		return ''
	}
	return f.last()
}

// hex_token parses the final token of a getevent line as a hex integer.
fn hex_token(line string) int {
	return parse_hex(last_token(line))
}

// parse_hex parses a hex string (no 0x prefix) into an int.
fn parse_hex(s string) int {
	mut v := 0
	for c in s {
		d := if c >= `0` && c <= `9` {
			int(c - `0`)
		} else if c >= `a` && c <= `f` {
			int(c - `a`) + 10
		} else if c >= `A` && c <= `F` {
			int(c - `A`) + 10
		} else {
			continue
		}
		v = v * 16 + d
	}
	return v
}

// --- selector synthesis ----------------------------------------------------

// synth_locator builds a semantic LocatorSpec for the node at `idx`, applying
// the same priority order as mobile/selectors.v so the generated source uses
// the most stable available selector.
pub fn synth_locator(platform Platform, nodes []UiNode, idx int) webdriver.LocatorSpec {
	node := nodes[idx]
	if platform == .android {
		return synth_android(nodes, idx, node)
	}
	return synth_ios(nodes, idx, node)
}

// synth_android: content-desc (unique) → resource-id (xpath) → text (unique)
// → role+text → positional xpath.
fn synth_android(nodes []UiNode, idx int, node UiNode) webdriver.LocatorSpec {
	cd := node.attrs['content-desc'] or { '' }
	if cd != '' && count_attr(nodes, 'content-desc', cd) == 1 {
		return webdriver.LocatorSpec{
			kind:  .test_id
			value: cd
		}
	}
	rid := node.attrs['resource-id'] or { '' }
	if rid != '' {
		return webdriver.LocatorSpec{
			kind:  .xpath
			value: '//*[@resource-id=${xpath_lit(rid)}]'
		}
	}
	txt := node.attrs['text'] or { '' }
	if txt != '' && count_attr(nodes, 'text', txt) == 1 {
		return webdriver.LocatorSpec{
			kind:  .text
			value: txt
		}
	}
	role := android_class_role(node.node_class())
	if role != '' {
		return webdriver.LocatorSpec{
			kind:  .role
			role:  role
			value: txt
		}
	}
	return webdriver.LocatorSpec{
		kind:  .xpath
		value: positional_xpath(nodes, idx)
	}
}

// synth_ios: name/accessibility-id (unique) → label (unique) → role+label →
// positional xpath.
fn synth_ios(nodes []UiNode, idx int, node UiNode) webdriver.LocatorSpec {
	name := node.attrs['name'] or { '' }
	if name != '' && count_attr(nodes, 'name', name) == 1 {
		return webdriver.LocatorSpec{
			kind:  .test_id
			value: name
		}
	}
	label := node.attrs['label'] or { '' }
	if label != '' && count_attr(nodes, 'label', label) == 1 {
		return webdriver.LocatorSpec{
			kind:  .label
			value: label
		}
	}
	role := ios_type_role(node.node_type())
	if role != '' {
		return webdriver.LocatorSpec{
			kind:  .role
			role:  role
			value: label
		}
	}
	return webdriver.LocatorSpec{
		kind:  .xpath
		value: positional_xpath(nodes, idx)
	}
}

// positional_xpath builds `(//<tag>)[n]` where n is the 1-based position of the
// node among same-tagged elements in document order — a unique fallback when
// no semantic attribute is available. The tag is the class on Android / the
// XCUIElementType on iOS, both valid as xpath element names on their backend.
fn positional_xpath(nodes []UiNode, idx int) string {
	tag := nodes[idx].tag
	mut n := 0
	for i := 0; i <= idx; i++ {
		if nodes[i].tag == tag {
			n++
		}
	}
	return '(//${tag})[${n}]'
}

// count_attr counts nodes whose `key` attribute equals `val` (val non-empty).
fn count_attr(nodes []UiNode, key string, val string) int {
	mut c := 0
	for n in nodes {
		if (n.attrs[key] or { '' }) == val {
			c++
		}
	}
	return c
}

// is_editable reports whether a node is a text-input field on its platform.
fn is_editable(platform Platform, node UiNode) bool {
	if platform == .android {
		return node.node_class().contains('EditText')
	}
	t := node.node_type()
	return t == 'XCUIElementTypeTextField' || t == 'XCUIElementTypeSecureTextField'
}

// current_field_text reads a node's current text/value from its parsed attrs.
fn current_field_text(node UiNode) string {
	if v := node.attrs['text'] {
		if v != '' {
			return v
		}
	}
	return node.attrs['value'] or { '' }
}

// android_class_role reverse-maps an android.widget class to a MobileRole
// string the emitter understands; '' when there's no clean mapping.
fn android_class_role(cls string) string {
	return match cls {
		'android.widget.Button', 'android.widget.ImageButton' { 'button' }
		'android.widget.EditText' { 'text_field' }
		'android.widget.TextView' { 'static_text' }
		'android.widget.ImageView' { 'image' }
		'android.widget.CheckBox' { 'checkbox' }
		'android.widget.Switch', 'android.widget.ToggleButton' { 'toggle' }
		else { '' }
	}
}

// ios_type_role reverse-maps an XCUIElementType to a MobileRole string; '' when
// there's no clean mapping.
fn ios_type_role(typ string) string {
	return match typ {
		'XCUIElementTypeButton' { 'button' }
		'XCUIElementTypeTextField', 'XCUIElementTypeSecureTextField' { 'text_field' }
		'XCUIElementTypeStaticText' { 'static_text' }
		'XCUIElementTypeImage' { 'image' }
		'XCUIElementTypeCheckBox' { 'checkbox' }
		'XCUIElementTypeSwitch' { 'toggle' }
		'XCUIElementTypeLink' { 'link' }
		else { '' }
	}
}

// role_from_string maps a role string (as stored on a LocatorSpec) back to the
// MobileRole enum so the recorder can rebuild a live locator.
fn role_from_string(s string) ?MobileRole {
	return match s {
		'button' { MobileRole.button }
		'text_field', 'textbox', 'textfield' { MobileRole.text_field }
		'static_text', 'text' { MobileRole.static_text }
		'image', 'img' { MobileRole.image }
		'checkbox' { MobileRole.checkbox }
		'toggle', 'switch' { MobileRole.toggle }
		'link' { MobileRole.link }
		else { none }
	}
}
