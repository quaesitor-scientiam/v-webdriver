module mobile

// Unit tests for the pure selector-escaping / quoting helpers. These are
// the most breakage-prone code in the module (a missed quote-escape sends
// a malformed predicate to the backend and the find silently fails), and
// they need no device — so they're worth locking down here.

fn test_escape_predicate_plain() {
	assert escape_predicate('General') == 'General'
	assert escape_predicate('') == ''
}

fn test_escape_predicate_single_quote() {
	// NSPredicate escapes a single-quote by doubling it.
	assert escape_predicate("O'Brien") == "O''Brien"
	assert escape_predicate("''") == "''''"
}

fn test_escape_uiselector_plain() {
	assert escape_uiselector('Battery') == 'Battery'
	assert escape_uiselector('') == ''
}

fn test_escape_uiselector_quotes_and_backslash() {
	// UiSelector lives in a double-quoted Java string literal: backslashes
	// and double-quotes both need escaping, backslash first.
	assert escape_uiselector('say "hi"') == 'say \\"hi\\"'
	assert escape_uiselector('a\\b') == 'a\\\\b'
	// Backslash must be escaped before the quote, else the escaped quote's
	// backslash would itself get doubled.
	assert escape_uiselector('a\\"b') == 'a\\\\\\"b'
}

fn test_xpath_lit_no_quotes() {
	assert xpath_lit('Settings') == '"Settings"'
}

fn test_xpath_lit_double_quote_only() {
	// Has " but no ' -> wrap in single quotes.
	assert xpath_lit('say "hi"') == '\'say "hi"\''
}

fn test_xpath_lit_single_quote_only() {
	// Has ' but no " -> wrap in double quotes.
	assert xpath_lit("O'Brien") == '"O\'Brien"'
}

fn test_xpath_lit_both_quotes() {
	// Has both -> concat() with the " pieces double-quoted and literal "
	// characters spliced in as single-quoted '"'.
	got := xpath_lit('a\'b"c')
	assert got == 'concat("a\'b", \'"\', "c")'
}

fn test_role_ios_type_mapping() {
	assert role_ios_type(.button) == 'XCUIElementTypeButton'
	assert role_ios_type(.text_field) == 'XCUIElementTypeTextField'
	assert role_ios_type(.toggle) == 'XCUIElementTypeSwitch'
	assert role_ios_type(.link) == 'XCUIElementTypeLink'
}

fn test_role_android_class_mapping() {
	assert role_android_class(.button) == 'android.widget.Button'
	assert role_android_class(.text_field) == 'android.widget.EditText'
	assert role_android_class(.toggle) == 'android.widget.Switch'
	// .link has no distinct Android widget — degrades to TextView, same as
	// .static_text. Pin that behavior so a future change is deliberate.
	assert role_android_class(.link) == 'android.widget.TextView'
	assert role_android_class(.static_text) == 'android.widget.TextView'
}

fn test_enable_disable() {
	assert enable_disable(true) == 'enable'
	assert enable_disable(false) == 'disable'
}
