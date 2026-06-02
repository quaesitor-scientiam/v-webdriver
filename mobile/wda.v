module mobile

import x.json2 as json
import vebidor.webdriver

// WDA HTTP client. WDA speaks W3C-compatible JSON over HTTP, so the
// wrappers here mirror the shape of `webdriver/client.v`'s post / get /
// post_void / delete_void. WebDriverResponse[T], ElementRef, and parse_error
// are imported from `vebidor.webdriver` — they're protocol-shaped, not
// browser-specific.

// post executes a JSON POST and decodes WebDriverResponse[T].
fn (s MobileSession) post[T](path string, payload json.Any) !webdriver.WebDriverResponse[T] {
	body := json.encode(payload)
	resp := s.transport.execute('POST', '${s.base_url}${path}', 'application/json', body) or {
		return error('POST ${path} failed: ${err}')
	}
	if resp.status_code >= 400 {
		e := webdriver.parse_error(resp.body) or {
			return error('POST ${path} failed (${resp.status_code}): ${resp.body}')
		}
		return error(e.str())
	}
	return json.decode[webdriver.WebDriverResponse[T]](resp.body) or {
		return error('Invalid response for ${path}: ${err}')
	}
}

// get_request executes a GET and decodes WebDriverResponse[T].
fn (s MobileSession) get_request[T](path string) !webdriver.WebDriverResponse[T] {
	resp := s.transport.execute('GET', '${s.base_url}${path}', '', '') or {
		return error('GET ${path} failed: ${err}')
	}
	if resp.status_code >= 400 {
		e := webdriver.parse_error(resp.body) or {
			return error('GET ${path} failed (${resp.status_code}): ${resp.body}')
		}
		return error(e.str())
	}
	return json.decode[webdriver.WebDriverResponse[T]](resp.body) or {
		return error('Invalid response for ${path}: ${err}')
	}
}

// post_void executes a JSON POST that doesn't return a useful value.
fn (s MobileSession) post_void(path string, payload json.Any) ! {
	body := json.encode(payload)
	resp := s.transport.execute('POST', '${s.base_url}${path}', 'application/json', body) or {
		return error('POST ${path} failed: ${err}')
	}
	if resp.status_code >= 400 {
		e := webdriver.parse_error(resp.body) or {
			return error('POST ${path} failed (${resp.status_code}): ${resp.body}')
		}
		return error(e.str())
	}
}

// delete_void executes a DELETE; used to tear down the session in close().
fn (s MobileSession) delete_void(path string) ! {
	s.transport.execute('DELETE', '${s.base_url}${path}', '', '') or {
		return error('DELETE ${path} failed: ${err}')
	}
}

// new_ios_session opens a fresh WDA session and returns a MobileSession
// ready for find / tap / fill / screenshot calls. Assumes WDA is already
// running at `base_url` — the bridge that auto-launches WDA lives in
// `bridges_ios.v` and is called from `launch_ios`.
pub fn new_ios_session(base_url string, bundle_id string) !MobileSession {
	probe := MobileSession{
		platform: .ios
		base_url: base_url
	}

	// W3C capabilities. WDA expects `platformName: 'iOS'`. `bundleId` (when
	// present) tells WDA which app to launch; omit it to attach to whatever
	// is in the foreground.
	mut always_match := map[string]json.Any{}
	always_match['platformName'] = json.Any('iOS')
	if bundle_id.len > 0 {
		always_match['bundleId'] = json.Any(bundle_id)
	}
	mut caps := map[string]json.Any{}
	caps['alwaysMatch'] = json.Any(always_match)
	caps['firstMatch'] = json.Any([json.Any(map[string]json.Any{})])
	mut req := map[string]json.Any{}
	req['capabilities'] = json.Any(caps)

	resp := probe.post[map[string]json.Any]('/session', json.Any(req))!
	sid_any := resp.value['sessionId'] or { return error('WDA session response missing sessionId') }
	return MobileSession{
		platform:   .ios
		base_url:   base_url
		session_id: sid_any.str()
	}
}

// find_element performs a single W3C find against the active session.
// `using` selects the strategy (`accessibility id`, `class chain`,
// `predicate string`, `xpath`); `value` is the strategy-specific
// expression. NOTE: raw WDA uses `predicate string` / `class chain`;
// Appium adds the `-ios ` prefix, but we talk to WDA directly here.
// expression.
pub fn (s MobileSession) find_element(using string, value string) !webdriver.ElementRef {
	resp := s.post[webdriver.ElementRef]('/session/${s.session_id}/element', s.find_payload(using,
		value))!
	return resp.value
}

// find_elements returns every match instead of the first.
pub fn (s MobileSession) find_elements(using string, value string) ![]webdriver.ElementRef {
	resp := s.post[[]webdriver.ElementRef]('/session/${s.session_id}/elements', s.find_payload(using,
		value))!
	return resp.value
}

// find_payload builds the element-finding request body in the dialect the
// backend expects. WDA (iOS) speaks the W3C `using`/`value` shape; the
// UiAutomator2 server (Android) wants its own `strategy`/`selector` keys.
// Appium's Node drivers translate between them — talking to the servers
// directly, we send each its native shape.
fn (s MobileSession) find_payload(using string, value string) json.Any {
	mut params := map[string]json.Any{}
	if s.platform == .android {
		params['strategy'] = json.Any(using)
		params['selector'] = json.Any(value)
	} else {
		params['using'] = json.Any(using)
		params['value'] = json.Any(value)
	}
	return json.Any(params)
}

// click_element sends a tap to the resolved element.
pub fn (s MobileSession) click_element(el webdriver.ElementRef) ! {
	s.post_void('/session/${s.session_id}/element/${el.element_id}/click',
		json.Any(map[string]json.Any{}))!
}

// send_keys types a string into the resolved element (text fields). WDA
// accepts both `text` and `value:[]string` shapes; we send `text` because
// it's the simpler one and works on every WDA version since 3.x.
pub fn (s MobileSession) send_keys(el webdriver.ElementRef, text string) ! {
	mut params := map[string]json.Any{}
	params['text'] = json.Any(text)
	s.post_void('/session/${s.session_id}/element/${el.element_id}/value', json.Any(params))!
}

// clear_element empties a text field.
pub fn (s MobileSession) clear_element(el webdriver.ElementRef) ! {
	s.post_void('/session/${s.session_id}/element/${el.element_id}/clear',
		json.Any(map[string]json.Any{}))!
}

// element_text returns the rendered text of the element.
pub fn (s MobileSession) element_text(el webdriver.ElementRef) !string {
	resp := s.get_request[string]('/session/${s.session_id}/element/${el.element_id}/text')!
	return resp.value
}

// is_element_displayed asks WDA whether the element is currently visible.
pub fn (s MobileSession) is_element_displayed(el webdriver.ElementRef) !bool {
	resp := s.get_request[bool]('/session/${s.session_id}/element/${el.element_id}/displayed')!
	return resp.value
}

// is_element_enabled asks WDA whether the element accepts input.
pub fn (s MobileSession) is_element_enabled(el webdriver.ElementRef) !bool {
	resp := s.get_request[bool]('/session/${s.session_id}/element/${el.element_id}/enabled')!
	return resp.value
}

// element_attribute reads a single XCUITest attribute (e.g. `name`,
// `label`, `value`, `enabled`, `accessible`).
pub fn (s MobileSession) element_attribute(el webdriver.ElementRef, name string) !string {
	resp :=
		s.get_request[string]('/session/${s.session_id}/element/${el.element_id}/attribute/${name}')!
	return resp.value
}

// page_source returns the full XCUITest element tree as XML — useful for
// debugging selectors and as the basis for an Inspector-style tool.
pub fn (s MobileSession) page_source() !string {
	resp := s.get_request[string]('/session/${s.session_id}/source')!
	return resp.value
}

// ElementRect is the on-screen bounding box of an element in CSS-pixel
// coordinates, as returned by WDA's /element/{}/rect endpoint. Gestures
// that act on element centers (long_press, swipe_*) use this to find the
// midpoint.
pub struct ElementRect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

// element_rect returns the on-screen rectangle of the element.
pub fn (s MobileSession) element_rect(el webdriver.ElementRef) !ElementRect {
	resp := s.get_request[ElementRect]('/session/${s.session_id}/element/${el.element_id}/rect')!
	return resp.value
}
