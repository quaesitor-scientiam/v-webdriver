module mobile

import x.json2 as json

// Device-state controls shared by both backends. WDA (iOS) and the
// UiAutomator2 server (Android) both implement the W3C-style
// `/session/{id}/orientation` endpoint with the same PORTRAIT/LANDSCAPE
// vocabulary, so orientation is a single cross-platform surface with no
// per-platform branching.

// Orientation is the device's screen orientation.
pub enum Orientation {
	portrait
	landscape
}

// str renders the orientation in the wire vocabulary both backends use.
fn (o Orientation) wire() string {
	return match o {
		.portrait { 'PORTRAIT' }
		.landscape { 'LANDSCAPE' }
	}
}

// orientation returns the device's current screen orientation.
pub fn (s MobileSession) orientation() !Orientation {
	resp := s.get_request[string]('/session/${s.session_id}/orientation')!
	return match resp.value {
		'LANDSCAPE' { Orientation.landscape }
		else { Orientation.portrait }
	}
}

// set_orientation rotates the device to the given orientation. Backends
// snap to the nearest supported rotation for that orientation.
pub fn (s MobileSession) set_orientation(o Orientation) ! {
	mut params := map[string]json.Any{}
	params['orientation'] = json.Any(o.wire())
	s.post_void('/session/${s.session_id}/orientation', json.Any(params))!
}
