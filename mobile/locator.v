module mobile

import time
import vebidor.webdriver

const default_timeout_ms = 30000
const default_poll_ms = 50

// MobileLocator is the lazy, auto-waiting handle to a mobile UI element —
// the equivalent of `webdriver.Locator` for the mobile side. Holds a
// reference to the session and a (strategy, value) pair; resolves on every
// use so a moved-or-rebuilt view tree doesn't strand a stale element id.
@[heap]
pub struct MobileLocator {
pub:
	session     &MobileSession
	using       string
	value       string
	timeout_ms  int = default_timeout_ms
	interval_ms int = default_poll_ms
}

// describe returns a short string identifying the locator (used in error
// messages from wait_for / wait_until_actionable / assertions).
pub fn (l MobileLocator) describe() string {
	return '${l.using}=${l.value}'
}

// find performs one resolution attempt against the backend. Errors if the
// element isn't present; callers usually want `wait_for` or
// `wait_until_actionable` instead.
pub fn (l MobileLocator) find() !webdriver.ElementRef {
	return l.session.find_element(l.using, l.value)
}

// find_all returns every element matching the locator (empty slice if
// none). Unlike `find`, it does not error on zero matches — use it to
// count or iterate. One resolution attempt, no auto-wait.
pub fn (l MobileLocator) find_all() ![]webdriver.ElementRef {
	return l.session.find_elements(l.using, l.value)
}

// wait_for polls until the element is present (resolves cleanly), then
// returns it. Mirrors `webdriver.Locator.wait_for`.
pub fn (l MobileLocator) wait_for() !webdriver.ElementRef {
	start := time.now()
	mut last := 'not found'
	for {
		if el := l.find() {
			return el
		} else {
			last = err.msg()
		}
		if time.now().unix_milli() - start.unix_milli() > i64(l.timeout_ms) {
			return error('locator "${l.describe()}" not found after ${l.timeout_ms}ms: ${last}')
		}
		time.sleep(l.interval_ms * time.millisecond)
	}
	return error('unreachable')
}

// wait_until_actionable polls until the element is present, displayed, and
// enabled — the mobile equivalent of the web's actionability check (we
// don't need scroll-into-view because WDA does that internally on tap).
pub fn (l MobileLocator) wait_until_actionable() !webdriver.ElementRef {
	start := time.now()
	mut last := 'unknown'
	for {
		if el := l.find() {
			disp := l.session.is_element_displayed(el) or {
				last = 'displayed check failed: ${err.msg()}'
				false
			}
			if disp {
				enab := l.session.is_element_enabled(el) or {
					last = 'enabled check failed: ${err.msg()}'
					false
				}
				if enab {
					return el
				} else {
					last = 'not enabled'
				}
			} else {
				last = 'not displayed'
			}
		} else {
			last = err.msg()
		}
		if time.now().unix_milli() - start.unix_milli() > i64(l.timeout_ms) {
			return error('locator "${l.describe()}" not actionable after ${l.timeout_ms}ms (${last})')
		}
		time.sleep(l.interval_ms * time.millisecond)
	}
	return error('unreachable')
}
