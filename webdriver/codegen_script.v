module webdriver

import sync
import x.json2 as json

// Web capture for the codegen recorder.
//
// A recorder script (recorder_js) is injected into the page over BiDi — as a
// preload script (runs before page scripts on every navigation) and, for the
// already-loaded document, evaluated immediately. It attaches capturing-phase
// listeners and, for each interaction, synthesizes a semantic selector
// (mirroring the get_by_* ladder in selectors.v, verified unique in-page) and
// reports a structured action back to V by writing a prefixed JSON line to the
// console. The Recorder subscribes to `log.entryAdded` (the same event the
// Tracer uses), parses those lines, and collects them as []RecordedAction.
//
// Console transport is used rather than a BiDi `script.message` channel because
// it needs zero new protocol surface — log.entryAdded is already wired and
// verified live. The prefix keeps recorder traffic separate from real console.

// rec_prefix marks a console line as a recorder message.
pub const rec_prefix = '__VEBIDOR_REC__'

// recorder_js is the in-page recorder, a function expression suitable for
// `script.addPreloadScript`. It uses only double quotes and backticks so the
// whole thing can live in a single-quoted V raw string. Backslash escapes are
// literal here and interpreted by the browser as JS.
pub const recorder_js = r'() => {
  if (window.__vebidorRec) return;
  window.__vebidorRec = true;
  const PFX = "__VEBIDOR_REC__";
  const send = (o) => { try { console.debug(PFX + JSON.stringify(o)); } catch (e) {} };
  const norm = (s) => (s || "").replace(/\s+/g, " ").trim();
  const all = (sel) => Array.from(document.querySelectorAll(sel));

  const implicitRole = (el) => {
    const tag = el.tagName.toLowerCase();
    if (tag === "a" && el.hasAttribute("href")) return "link";
    if (tag === "button") return "button";
    if (tag === "select") return "combobox";
    if (tag === "textarea") return "textbox";
    if (/^h[1-6]$/.test(tag)) return "heading";
    if (tag === "img") return "img";
    if (tag === "nav") return "navigation";
    if (tag === "input") {
      const t = (el.getAttribute("type") || "text").toLowerCase();
      if (t === "checkbox") return "checkbox";
      if (t === "radio") return "radio";
      if (["button", "submit", "reset", "image"].includes(t)) return "button";
      return "textbox";
    }
    return "";
  };
  const roleOf = (el) => el.getAttribute("role") || implicitRole(el);

  const accName = (el) => {
    const al = el.getAttribute("aria-label");
    if (al) return norm(al);
    const lb = el.getAttribute("aria-labelledby");
    if (lb) { const r = document.getElementById(lb); if (r) return norm(r.textContent); }
    if (el.tagName.toLowerCase() === "img") { const a = el.getAttribute("alt"); if (a) return norm(a); }
    const tx = norm(el.textContent);
    if (tx) return tx;
    const ti = el.getAttribute("title");
    if (ti) return norm(ti);
    return "";
  };

  const roleMatches = (role) => {
    const map = {
      button: "button, input[type=button], input[type=submit], input[type=reset], input[type=image], [role=button]",
      link: "a[href], [role=link]",
      checkbox: "input[type=checkbox], [role=checkbox]",
      radio: "input[type=radio], [role=radio]",
      textbox: "input:not([type]), input[type=text], input[type=search], input[type=email], input[type=url], input[type=tel], input[type=password], textarea, [role=textbox]",
      heading: "h1,h2,h3,h4,h5,h6,[role=heading]",
      img: "img, [role=img]",
      combobox: "select, [role=combobox]"
    };
    return all(map[role] || ("[role=" + role + "]"));
  };
  const nameMatch = (el, name) => norm(el.textContent) === name || el.getAttribute("aria-label") === name || el.getAttribute("title") === name;

  const labelText = (el) => {
    const al = el.getAttribute("aria-label"); if (al) return norm(al);
    if (el.id) { const l = document.querySelector(`label[for="${el.id}"]`); if (l) return norm(l.textContent); }
    const wrap = el.closest("label"); if (wrap) return norm(wrap.textContent);
    return "";
  };
  const labelMatches = (text) => {
    const out = [];
    document.querySelectorAll("input, textarea, select").forEach((c) => { if (labelText(c) === text) out.push(c); });
    document.querySelectorAll("[aria-label]").forEach((c) => { if (norm(c.getAttribute("aria-label")) === text && out.indexOf(c) < 0) out.push(c); });
    return out;
  };

  const isLeaf = (el) => el.children.length === 0;
  const textMatches = (text) => all("*").filter((e) => isLeaf(e) && norm(e.textContent).includes(text));

  const cssPath = (el) => {
    if (el.id && all(`#${CSS.escape(el.id)}`).length === 1) return `#${CSS.escape(el.id)}`;
    const parts = [];
    let cur = el;
    while (cur && cur.nodeType === 1 && cur !== document.documentElement) {
      let s = cur.tagName.toLowerCase();
      const par = cur.parentElement;
      if (par) {
        const sib = Array.from(par.children).filter((c) => c.tagName === cur.tagName);
        if (sib.length > 1) s += `:nth-of-type(${sib.indexOf(cur) + 1})`;
      }
      parts.unshift(s);
      cur = cur.parentElement;
    }
    return parts.join(" > ");
  };

  const describe = (el) => {
    const tid = el.getAttribute("data-testid");
    if (tid && all(`[data-testid="${CSS.escape(tid)}"]`).length === 1) return { kind: "test_id", value: tid, role: "", nth: -1 };
    const role = roleOf(el), name = accName(el);
    if (role && name) { const m = roleMatches(role).filter((e) => nameMatch(e, name)); if (m.length === 1 && m[0] === el) return { kind: "role", value: name, role: role, nth: -1 }; }
    const ph = el.getAttribute("placeholder");
    if (ph && all(`[placeholder="${CSS.escape(ph)}"]`).length === 1) return { kind: "placeholder", value: ph, role: "", nth: -1 };
    const lt = labelText(el);
    if (lt) { const m = labelMatches(lt); if (m.length === 1 && m[0] === el) return { kind: "label", value: lt, role: "", nth: -1 }; }
    const tx = norm(el.textContent);
    if (tx && tx.length <= 80) { const m = textMatches(tx); if (m.length === 1 && m[0] === el) return { kind: "text", value: tx, role: "", nth: -1 }; }
    return { kind: "css", value: cssPath(el), role: "", nth: -1 };
  };

  const interactive = (el) => el.closest("button, a[href], input, select, textarea, [role=button], [role=link], [role=checkbox], [onclick]") || el;

  document.addEventListener("click", (ev) => {
    const el = interactive(ev.target);
    if (!el) return;
    if (ev.altKey) {
      const sel = describe(el), tx = norm(el.textContent);
      if (tx) send({ action: "assert_text", sel: sel, value: tx });
      else send({ action: "assert_visible", sel: sel, value: "" });
      return;
    }
    const tag = el.tagName.toLowerCase(), t = (el.getAttribute("type") || "").toLowerCase();
    if (tag === "input" && (t === "checkbox" || t === "radio")) { send({ action: "check", sel: describe(el), value: "" }); return; }
    send({ action: "click", sel: describe(el), value: "" });
  }, true);

  document.addEventListener("change", (ev) => {
    const el = ev.target, tag = el.tagName.toLowerCase(), t = (el.getAttribute("type") || "").toLowerCase();
    if (tag === "select") { const o = el.options[el.selectedIndex]; send({ action: "select_option", sel: describe(el), value: norm(o ? o.textContent : el.value) }); return; }
    if (tag === "input" && (t === "checkbox" || t === "radio")) return;
    if (tag === "input" || tag === "textarea") send({ action: "fill", sel: describe(el), value: el.value });
  }, true);

  document.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter") {
      const el = ev.target, tag = el.tagName.toLowerCase();
      if (tag === "input" || tag === "textarea") send({ action: "press", sel: describe(el), value: "Enter" });
    }
  }, true);
}'

// Recorder collects RecordedActions from an instrumented page over a BiDi
// connection. Inject + subscribe with start(); read with actions() / emit_web().
@[heap]
pub struct Recorder {
mut:
	bidi      &BiDi       = unsafe { nil }
	mu        &sync.Mutex = unsafe { nil }
	actions   []RecordedAction
	script_id string
}

// new_recorder creates a recorder bound to this BiDi connection.
pub fn (mut b BiDi) new_recorder() &Recorder {
	return &Recorder{
		bidi: &b
		mu:   sync.new_mutex()
	}
}

// start injects the recorder script (as a preload script for future
// navigations and immediately into the current document) and begins listening
// for recorded actions on the console log.
pub fn (mut r Recorder) start() ! {
	mut b := r.bidi
	r.script_id = b.add_preload_script(recorder_js)!

	// Install into the already-loaded document(s) too — preload only affects
	// future navigations.
	for ctx in b.browsing_contexts()! {
		b.evaluate(ctx, '(' + recorder_js + ')()') or {}
	}

	rptr := voidptr(r)
	b.on_sync('log.entryAdded', fn [rptr] (params json.Any) {
		mut rr := unsafe { &Recorder(rptr) }
		text := (params.as_map()['text'] or { json.Any('') }).str()
		rr.ingest(text)
	})
	b.subscribe(['log.entryAdded'])!
}

// ingest parses one console line; non-recorder lines are ignored.
fn (mut r Recorder) ingest(text string) {
	if !text.starts_with(rec_prefix) {
		return
	}
	obj := json.decode[json.Any](text[rec_prefix.len..]) or { return }
	act := parse_recorded(obj) or { return }
	r.mu.lock()
	r.actions << act
	r.mu.unlock()
}

// actions returns a snapshot of the recorded actions so far.
pub fn (mut r Recorder) actions() []RecordedAction {
	r.mu.lock()
	a := r.actions.clone()
	r.mu.unlock()
	return a
}

// emit_web renders the recorded session as a runnable V program.
pub fn (mut r Recorder) emit_web() string {
	return emit_v_web(r.actions())
}

// parse_kind maps a wire selector-kind string onto a SelectorKind (css default).
fn parse_kind(s string) SelectorKind {
	return match s {
		'test_id' { SelectorKind.test_id }
		'role' { SelectorKind.role }
		'label' { SelectorKind.label }
		'placeholder' { SelectorKind.placeholder }
		'text' { SelectorKind.text }
		'xpath' { SelectorKind.xpath }
		else { SelectorKind.css }
	}
}

// parse_recorded turns a decoded recorder message into a RecordedAction, or
// none if the action kind is unknown.
fn parse_recorded(obj json.Any) ?RecordedAction {
	m := obj.as_map()
	action := (m['action'] or { return none }).str()
	selm := (m['sel'] or { json.Any(map[string]json.Any{}) }).as_map()
	spec := LocatorSpec{
		kind:  parse_kind((selm['kind'] or { json.Any('css') }).str())
		value: (selm['value'] or { json.Any('') }).str()
		role:  (selm['role'] or { json.Any('') }).str()
		nth:   (selm['nth'] or { json.Any(-1) }).int()
	}
	value := (m['value'] or { json.Any('') }).str()
	kind := match action {
		'goto' { ActionKind.goto }
		'click' { ActionKind.click }
		'fill' { ActionKind.fill }
		'press' { ActionKind.press }
		'check' { ActionKind.check }
		'select_option' { ActionKind.select_option }
		'assert_visible' { ActionKind.assert_visible }
		'assert_text' { ActionKind.assert_text }
		'assert_contain_text' { ActionKind.assert_contain_text }
		else { return none }
	}

	return RecordedAction{
		kind:   kind
		target: spec
		value:  value
	}
}
