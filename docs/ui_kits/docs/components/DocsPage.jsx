/* global React, CodeBlock, Callout, ComparisonTable, ApiSignature */
const { useState: usDS } = React;

const dpStyles = {
  page: { maxWidth: 760, margin: 0 },
  breadcrumb: { fontFamily: "var(--font-sans)", fontSize: 12.5, color: "var(--fg-3)", marginBottom: 14 },
  breadcrumb_b: { color: "var(--fg-2)" },
  h1: { fontFamily: "var(--font-sans)", fontWeight: 800, fontSize: 40, lineHeight: 1.1, letterSpacing: "-0.025em", margin: "0 0 12px", color: "var(--fg-1)" },
  lede: { fontFamily: "var(--font-sans)", fontSize: 19, lineHeight: 1.5, color: "var(--fg-2)", margin: "0 0 32px" },
  h2: { fontFamily: "var(--font-sans)", fontWeight: 700, fontSize: 26, lineHeight: 1.25, letterSpacing: "-0.02em", margin: "44px 0 12px", color: "var(--fg-1)" },
  h3: { fontFamily: "var(--font-sans)", fontWeight: 600, fontSize: 19, lineHeight: 1.3, margin: "30px 0 8px", color: "var(--fg-1)" },
  p: { fontFamily: "var(--font-sans)", fontSize: 16, lineHeight: 1.65, color: "var(--fg-1)", margin: "0 0 16px", textWrap: "pretty" },
  ul: { margin: "0 0 16px", paddingLeft: 22, fontFamily: "var(--font-sans)", fontSize: 16, lineHeight: 1.65, color: "var(--fg-1)" },
  li: { marginBottom: 4 },
  footer: { display: "flex", justifyContent: "space-between", gap: 12, marginTop: 64, paddingTop: 24, borderTop: "1px solid var(--border-1)" },
  fbtn: { flex: 1, padding: "14px 16px", border: "1px solid var(--border-1)", borderRadius: "var(--radius-lg)", background: "#fff", color: "var(--fg-1)", textDecoration: "none", fontFamily: "var(--font-sans)", fontSize: 14, cursor: "pointer" },
  fbtn_label: { fontSize: 11, color: "var(--fg-3)", textTransform: "uppercase", letterSpacing: "0.04em", display: "block", marginBottom: 4 },
  fbtn_title: { fontWeight: 600 },
  inlineCode: { fontFamily: "var(--font-mono)", fontSize: "0.9em", background: "var(--surface-2)", color: "var(--fg-1)", padding: "0.12em 0.4em", borderRadius: 4, border: "1px solid var(--border-1)" },
};

const C = (text) => <code style={dpStyles.inlineCode}>{text}</code>;

// ───────── PAGE: Quick Start ─────────
function PageQuickStart({ onNavigate }) {
  const nav = (id) => (e) => { e.preventDefault(); onNavigate && onNavigate(id); };
  return (
    <article style={dpStyles.page}>
      <div style={dpStyles.breadcrumb}>Getting started <span style={{ margin: "0 6px", color: "var(--fg-4)" }}>/</span> <span style={dpStyles.breadcrumb_b}>Quick start</span></div>
      <h1 id="quick-start" style={dpStyles.h1}>Quick start</h1>
      <p style={dpStyles.lede}>Get a browser launched, a page navigated, and an assertion polling in three lines of V — no manual driver setup.</p>

      <h2 id="install" style={dpStyles.h2}>Install</h2>
      <p style={dpStyles.p}>Add Vebidor to your <code style={dpStyles.inlineCode}>v.mod</code> dependencies and pull it in with a single import.</p>
      <CodeBlock lang="vlang" filename="v.mod" lines={[
        [{ t: "Module {" }],
        [{ t: "  ", k: null }, { t: "name:", k: "keyword" }, { t: " ", k: null }, { t: "'my-bot'", k: "string" }],
        [{ t: "  ", k: null }, { t: "dependencies:", k: "keyword" }, { t: " [", k: null }, { t: "'vebidor'", k: "string" }, { t: "]", k: null }],
        [{ t: "}" }],
      ]} />

      <h2 id="first-script" style={dpStyles.h2}>Your first script</h2>
      <p style={dpStyles.p}>{C('launch_edge()')} locates the driver on <code style={dpStyles.inlineCode}>PATH</code>, picks a free port, opens a session, and tears everything down on <code style={dpStyles.inlineCode}>close()</code>.</p>
      <CodeBlock lang="vlang" filename="example_quick_start.v" showLineNumbers lines={[
        [{ t: "import", k: "keyword" }, { t: " vebidor.webdriver" }],
        [{ t: "" }],
        [{ t: "fn", k: "keyword" }, { t: " " }, { t: "main", k: "function" }, { t: "() {" }],
        [{ t: "  mut", k: "keyword" }, { t: " b := webdriver." }, { t: "launch_edge", k: "function" }, { t: "(webdriver." }, { t: "LaunchOptions", k: "type" }, { t: "{ headless: " }, { t: "true", k: "keyword" }, { t: " })!" }],
        [{ t: "  defer", k: "keyword" }, { t: " { b." }, { t: "close", k: "function" }, { t: "() }" }],
        [{ t: "" }],
        [{ t: "  b." }, { t: "goto", k: "function" }, { t: "(" }, { t: "'https://example.com'", k: "string" }, { t: ")!" }],
        [{ t: "  webdriver." }, { t: "expect", k: "function" }, { t: "(b.wd." }, { t: "get_by_role", k: "function" }, { t: "(" }, { t: "'heading'", k: "string" }, { t: ", " }, { t: "''", k: "string" }, { t: "))." }, { t: "to_be_visible", k: "function" }, { t: "()!" }],
        [{ t: "}" }],
      ]} />

      <Callout kind="info" title="What just happened?">
        <p style={{ margin: 0 }}>{C('expect()')} polls the locator for up to 30 seconds. The heading doesn't need to be in the DOM yet — Vebidor will wait for it.</p>
      </Callout>

      <h2 id="run" style={dpStyles.h2}>Run it</h2>
      <CodeBlock lang="bash" filename="terminal" lines={[
        [{ t: "$ ", k: "comment" }, { t: "v run example_quick_start.v" }],
        [{ t: "✓ heading: \"Example Domain\"", k: "string" }],
      ]} />

      <h2 id="next" style={dpStyles.h2}>Next steps</h2>
      <ul style={dpStyles.ul}>
        <li style={dpStyles.li}><a href="#modern-api" onClick={nav("modern-api")}>Modern API</a> — Locators, selectors, retrying assertions</li>
        <li style={dpStyles.li}><a href="#bidi" onClick={nav("bidi")}>WebDriver-BiDi</a> — network interception, isolated contexts, mobile emulation</li>
        <li style={dpStyles.li}><a href="#comparison" onClick={nav("comparison")}>Comparison with Selenium &amp; Playwright</a> — feature-by-feature</li>
      </ul>
    </article>
  );
}

// ───────── PAGE: Modern API ─────────
function PageModernApi() {
  return (
    <article style={dpStyles.page}>
      <div style={dpStyles.breadcrumb}>API reference <span style={{ margin: "0 6px", color: "var(--fg-4)" }}>/</span> <span style={dpStyles.breadcrumb_b}>Modern API</span></div>
      <h1 id="modern-api" style={dpStyles.h1}>Modern API <span className="chip chip--info" style={{ verticalAlign: "middle", marginLeft: 10, fontSize: 11 }}>✨ Playwright-style</span></h1>
      <p style={dpStyles.lede}>Lazy auto-waiting <code style={dpStyles.inlineCode}>Locator</code>s, semantic selector engines, and web-first retrying assertions — on top of the raw W3C WebDriver client.</p>

      <h2 id="locators" style={dpStyles.h2}>Locators</h2>
      <p style={dpStyles.p}>A {C('Locator')} is a <em>lazy</em> handle to an element. Unlike {C('ElementRef')}, it does not capture a specific element id up front — it stores the selection criteria and re-resolves on every use, so it's immune to staleness from DOM re-renders.</p>

      <ApiSignature
        name="get_by_role"
        params={[
          { name: "role", type: "string", note: "ARIA role: 'button', 'heading', 'link', …" },
          { name: "name", type: "string", note: "accessible name (substring match); '' to skip" },
        ]}
        returns="Locator"
        description="Return a locator targeting the first element with the given ARIA role and accessible name."
      />

      <h3 id="actions" style={dpStyles.h3}>Auto-waiting actions</h3>
      <p style={dpStyles.p}>Actions on a {C('Locator')} wait for the element to be attached, visible, enabled, and scrolled into view before acting.</p>
      <CodeBlock lang="vlang" lines={[
        [{ t: "b.wd." }, { t: "get_by_role", k: "function" }, { t: "(" }, { t: "'button'", k: "string" }, { t: ", " }, { t: "'Submit'", k: "string" }, { t: ")." }, { t: "click", k: "function" }, { t: "()!" }],
        [{ t: "b.wd." }, { t: "get_by_label", k: "function" }, { t: "(" }, { t: "'Email'", k: "string" }, { t: ")." }, { t: "fill", k: "function" }, { t: "(" }, { t: "'me@example.com'", k: "string" }, { t: ")!" }],
      ]} />

      <h2 id="assertions" style={dpStyles.h2}>Web-first assertions</h2>
      <p style={dpStyles.p}>{C('expect(loc).to_be_visible()')} polls the locator until the condition holds — no manual <code style={dpStyles.inlineCode}>sleep</code> required. Invert with {C('.not()')}, customize timeout with {C('.with_timeout(ms)')}.</p>
      <CodeBlock lang="vlang" lines={[
        [{ t: "webdriver.", k: null }, { t: "expect", k: "function" }, { t: "(loc)." }, { t: "to_have_text", k: "function" }, { t: "(" }, { t: "'Welcome'", k: "string" }, { t: ")!" }],
        [{ t: "webdriver.", k: null }, { t: "expect", k: "function" }, { t: "(loc)." }, { t: "not", k: "function" }, { t: "()." }, { t: "to_be_disabled", k: "function" }, { t: "()." }, { t: "with_timeout", k: "function" }, { t: "(" }, { t: "5000", k: "number" }, { t: ")!" }],
      ]} />

      <Callout kind="warning" title="One known limit">
        <p style={{ margin: 0 }}>Real <code style={dpStyles.inlineCode}>touchstart</code>/<code style={dpStyles.inlineCode}>touchend</code> events need driver-level touch emulation (CDP / mobileEmulation capability), which WebDriver-BiDi doesn't expose. {C('tap()')} synthesizes a click.</p>
      </Callout>
    </article>
  );
}

// ───────── PAGE: WebDriver-BiDi ─────────
function PageBiDi() {
  return (
    <article style={dpStyles.page}>
      <div style={dpStyles.breadcrumb}>API reference <span style={{ margin: "0 6px", color: "var(--fg-4)" }}>/</span> <span style={dpStyles.breadcrumb_b}>WebDriver-BiDi</span></div>
      <h1 id="bidi" style={dpStyles.h1}>WebDriver-BiDi <span className="emoji" style={{ fontSize: 28 }}>🎭</span></h1>
      <p style={dpStyles.lede}>Launch with {C('bidi: true')} to get a persistent WebSocket alongside the Classic session — network mocking, console events, isolated contexts, and more.</p>

      <h2 id="network-mocking" style={dpStyles.h2}>Network mocking</h2>
      <p style={dpStyles.p}>Intercept and rewrite responses with {C('route')} (Playwright-style). There is no Classic-WebDriver equivalent for this.</p>
      <CodeBlock lang="vlang" filename="example_bidi.v" lines={[
        [{ t: "mut", k: "keyword" }, { t: " b := webdriver." }, { t: "launch_edge", k: "function" }, { t: "(webdriver." }, { t: "LaunchOptions", k: "type" }, { t: "{" }],
        [{ t: "  headless: " }, { t: "true", k: "keyword" }, { t: ", bidi: " }, { t: "true", k: "keyword" }],
        [{ t: "})!" }],
        [{ t: "mut", k: "keyword" }, { t: " bidi := b." }, { t: "bidi", k: "function" }, { t: "()!" }],
        [{ t: "" }],
        [{ t: "bidi." }, { t: "route", k: "function" }, { t: "(" }, { t: "fn", k: "keyword" }, { t: " (req webdriver." }, { t: "InterceptedRequest", k: "type" }, { t: ") {" }],
        [{ t: "  ", k: null }, { t: "if", k: "keyword" }, { t: " req.url." }, { t: "contains", k: "function" }, { t: "(" }, { t: "'/api'", k: "string" }, { t: ") {" }],
        [{ t: "    req." }, { t: "fulfill", k: "function" }, { t: "(" }, { t: "200", k: "number" }, { t: ", " }, { t: "'application/json'", k: "string" }, { t: ", " }, { t: "'{\"mocked\":true}'", k: "string" }, { t: ") or {}" }],
        [{ t: "  } " }, { t: "else", k: "keyword" }, { t: " {" }],
        [{ t: "    req." }, { t: "continue_request", k: "function" }, { t: "() or {}" }],
        [{ t: "  }" }],
        [{ t: "})!" }],
      ]} />

      <Callout kind="success" title="Verified live">
        <p style={{ margin: 0 }}>Every BiDi feature listed is verified against headless Edge. Capability probing via {C('status()')} / {C('supports()')} lets your scripts adapt to what a given driver actually implements.</p>
      </Callout>

      <h2 id="contexts" style={dpStyles.h2}>Isolated user contexts</h2>
      <p style={dpStyles.p}>Equivalent to Playwright's {C('browser.newContext()')}. Per-context proxy, geolocation, permissions, and storageState session reuse.</p>
    </article>
  );
}

// ───────── PAGE: Comparison ─────────
function PageComparison() {
  return (
    <article style={dpStyles.page}>
      <div style={dpStyles.breadcrumb}>Reference <span style={{ margin: "0 6px", color: "var(--fg-4)" }}>/</span> <span style={dpStyles.breadcrumb_b}>Comparison</span></div>
      <h1 id="comparison" style={dpStyles.h1}>Comparison <span className="emoji" style={{ fontSize: 26 }}>🎯</span></h1>
      <p style={dpStyles.lede}>Vebidor sits between Selenium (peer) and Playwright (newer generation). This is where it lands feature-for-feature.</p>

      <h2 id="vs-playwright" style={dpStyles.h2}>vs Playwright</h2>
      <ComparisonTable
        columns={[
          { label: "Feature", width: "38%" },
          { label: "Vebidor", width: "16%" },
          { label: "Playwright", width: "14%" },
          { label: "Notes" },
        ]}
        rows={[
          ["Auto-waiting actions",                  { chip: "Built-in", kind: "success", em: "✅" }, { chip: "Yes", kind: "success", em: "✅" }, "visible + enabled + scrolled-into-view"],
          ["Web-first assertions",                  { chip: "Yes", kind: "success", em: "✅" }, { chip: "Yes", kind: "success", em: "✅" }, <span>polling, <code style={dpStyles.inlineCode}>.not()</code> / <code style={dpStyles.inlineCode}>.with_timeout()</code></span>],
          ["Network mocking",                       { chip: "BiDi", kind: "success", em: "✅" }, { chip: "Yes", kind: "success", em: "✅" }, "route / fulfill / abort / continue"],
          ["Standards-based transport",             { chip: "W3C", kind: "milestone", em: "🏆" }, { chip: "CDP", kind: "neutral", em: "" }, "talks to any conformant driver, incl. Safari"],
          ["Real touch-event dispatch",             { chip: "Protocol limit", kind: "warning", em: "⚠️" }, { chip: "Yes", kind: "success", em: "✅" }, "BiDi doesn't expose CDP touch"],
          ["Codegen recorder",                      { chip: "Deferred", kind: "neutral", em: "" }, { chip: "Yes", kind: "success", em: "✅" }, "high effort, low value"],
        ]}
      />

      <h2 id="phases" style={dpStyles.h2}>Phase history</h2>
      <p style={dpStyles.p}>Vebidor's release notes are organized around <strong>Phases</strong> — each one closes a specific gap relative to Selenium or Playwright.</p>
      <ul style={dpStyles.ul}>
        <li style={dpStyles.li}><strong>Phase 1–8</strong> — Selenium parity (element properties, alerts, page info, window mgmt, CSS, expected conditions, advanced actions, async/shadow). <span className="chip chip--milestone" style={{ marginLeft: 6 }}><span className="emoji">🏆</span> 100%</span></li>
        <li style={dpStyles.li}><strong>Phase 0–5 (Playwright)</strong> — transport seam, locators, launch(), BiDi transport, BiDi features, tooling. <span className="chip chip--success" style={{ marginLeft: 6 }}><span className="emoji">✅</span> shipped</span></li>
        <li style={dpStyles.li}><strong>v4.2.0</strong> — mobile-web emulation (device presets, viewport/UA/touch, locale/timezone). <span className="chip chip--info" style={{ marginLeft: 6 }}><span className="emoji">✨</span> new</span></li>
      </ul>
    </article>
  );
}

// ───────── PAGE: Mobile (preview) ─────────
function PageMobile() {
  return (
    <article style={dpStyles.page}>
      <div style={dpStyles.breadcrumb}>API reference <span style={{ margin: "0 6px", color: "var(--fg-4)" }}>/</span> <span style={dpStyles.breadcrumb_b}>Mobile</span></div>
      <h1 id="mobile" style={dpStyles.h1}>
        Mobile <span className="chip chip--success" style={{ verticalAlign: "middle", marginLeft: 10, fontSize: 11 }}>✅ Shipped · v5.0.0</span>
      </h1>
      <p style={dpStyles.lede}>
        A native mobile module that skips Appium entirely. Talk to <strong>WebDriverAgent</strong> on iOS and the <strong>UiAutomator2 server</strong> on Android over their native sockets — the same protocols Appium uses, minus the Node middleware.
      </p>

      <Callout kind="success" title="Status: shipped in v5.0.0">
        <p style={{ margin: 0 }}>
          The <code style={dpStyles.inlineCode}>vebidor.mobile</code> module is implemented (Mob-1 → Mob-6.1): sessions, lazy auto-waiting locators, cross-platform <code style={dpStyles.inlineCode}>get_by_*</code> selectors, <code style={dpStyles.inlineCode}>expect()</code> assertions, touch gestures, app lifecycle, and device state. The Android path is verified live on an emulator; iOS on a Simulator. See <strong>COMPARISON_WITH_APPIUM.md</strong> and <strong>MOBILE_TESTING.md</strong>.
        </p>
      </Callout>

      <h2 id="speed-comes-from" style={dpStyles.h2}>Where speed actually comes from</h2>
      <p style={dpStyles.p}>
        Mobile test runners split into two tiers: <strong>in-process</strong> (test code runs inside the app's process and syncs with the runloop) and <strong>out-of-process</strong> (test code drives the device over a socket). In-process is fastest but locks you into the app's language. Vebidor's slot is the fastest-possible <em>out-of-process</em> tier.
      </p>
      <ComparisonTable
        columns={[
          { label: "Tool", width: "20%" },
          { label: "Tier", width: "20%" },
          { label: "Fast because…", width: "32%" },
          { label: "Cost" },
        ]}
        rows={[
          ["Espresso (Android)",  "In-process",     "Syncs with main looper + AsyncTask — zero polling",       "Must be the app · JVM · rebuild"],
          ["EarlGrey 2 (iOS)",    "Out-of-process", "XCUITest + injected satellite framework syncs with AUT runloop", "Swift/Obj-C · embed sync lib"],
          ["Detox (RN only)",     "In-process",     "Hooks RN's bridge / Hermes idle signals",                  "React Native only"],
          ["Maestro",             "Out-of-process", "Direct sockets to idb_companion + UiAutomator2",           "Less granular than full WebDriver"],
          ["Appium",              "Out-of-process", { chip: "Multi-hop", kind: "warning", em: "⚠️" },           "HTTP → Node → vendor → device"],
          [<strong>Vebidor mobile</strong>, <span className="chip chip--success" style={{ fontSize: 11 }}>✅ Shipped</span>, "Native V client → WDA / UiAutomator2 sockets, no Appium",  "Out-of-process · still can't beat in-process"],
        ]}
      />

      <h2 id="architecture" style={dpStyles.h2}>Architecture</h2>
      <p style={dpStyles.p}>
        One <code style={dpStyles.inlineCode}>vebidor.mobile</code> API surface, two backends. Each backend speaks its platform's automation protocol natively from V — no Appium server, no JSON-Wire-over-HTTP-over-Node hop.
      </p>

      <div style={archStyles.frame}>
        <svg viewBox="0 0 720 360" width="100%" style={{ maxWidth: 720, display: "block", margin: "0 auto" }} role="img" aria-label="Mobile backend architecture">
          <defs>
            <marker id="arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto">
              <path d="M0,0 L10,5 L0,10 z" fill="#475569" />
            </marker>
          </defs>

          {/* Tier label: code */}
          <text x="20" y="32" fontFamily="Geist, sans-serif" fontSize="11" fontWeight="600" fill="#94A3B8" letterSpacing="0.06em">USER CODE</text>
          {/* User code box */}
          <rect x="180" y="14" width="360" height="46" rx="8" fill="#0B1220" stroke="#1E293B"/>
          <text x="360" y="42" textAnchor="middle" fontFamily="JetBrains Mono, monospace" fontSize="13" fill="#C0CAF5">
            <tspan fill="#7AA2F7">b</tspan>
            <tspan>.</tspan>
            <tspan fill="#E0AF68">mobile</tspan>
            <tspan>.</tspan>
            <tspan fill="#E0AF68">tap</tspan>
            <tspan>(</tspan>
            <tspan fill="#E0AF68">by_text</tspan>
            <tspan>(</tspan>
            <tspan fill="#9ECE6A">'Sign in'</tspan>
            <tspan>))!</tspan>
          </text>
          {/* arrow down */}
          <line x1="360" y1="60" x2="360" y2="92" stroke="#475569" strokeWidth="1.5" markerEnd="url(#arr)"/>

          {/* Tier label: vebidor */}
          <text x="20" y="118" fontFamily="Geist, sans-serif" fontSize="11" fontWeight="600" fill="#94A3B8" letterSpacing="0.06em">VEBIDOR</text>
          {/* Vebidor box */}
          <rect x="180" y="98" width="360" height="60" rx="10" fill="#EEF3FF" stroke="#3E63DD" strokeWidth="1.5"/>
          <text x="360" y="122" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="14" fontWeight="600" fill="#1E3A8A">vebidor.mobile</text>
          <text x="360" y="142" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="11.5" fill="#475569">one API · auto-waiting locators · batched flows</text>

          {/* fork lines */}
          <line x1="280" y1="158" x2="200" y2="200" stroke="#475569" strokeWidth="1.5" markerEnd="url(#arr)"/>
          <line x1="440" y1="158" x2="520" y2="200" stroke="#475569" strokeWidth="1.5" markerEnd="url(#arr)"/>

          {/* Tier label: backends */}
          <text x="20" y="226" fontFamily="Geist, sans-serif" fontSize="11" fontWeight="600" fill="#94A3B8" letterSpacing="0.06em">BACKENDS</text>

          {/* iOS box */}
          <rect x="60" y="208" width="280" height="58" rx="10" fill="#FFFFFF" stroke="#CBD5E1"/>
          <text x="200" y="231" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="14" fontWeight="600" fill="#0F172A">iOS · WebDriverAgent</text>
          <text x="200" y="250" textAnchor="middle" fontFamily="JetBrains Mono, monospace" fontSize="11" fill="#64748B">TCP / JSON Wire via idb · go-ios</text>

          {/* Android box */}
          <rect x="380" y="208" width="280" height="58" rx="10" fill="#FFFFFF" stroke="#CBD5E1"/>
          <text x="520" y="231" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="14" fontWeight="600" fill="#0F172A">Android · UiAutomator2</text>
          <text x="520" y="250" textAnchor="middle" fontFamily="JetBrains Mono, monospace" fontSize="11" fill="#64748B">TCP / JSON Wire via adb forward</text>

          {/* arrows to devices */}
          <line x1="200" y1="266" x2="200" y2="298" stroke="#475569" strokeWidth="1.5" markerEnd="url(#arr)"/>
          <line x1="520" y1="266" x2="520" y2="298" stroke="#475569" strokeWidth="1.5" markerEnd="url(#arr)"/>

          {/* Tier label: devices */}
          <text x="20" y="324" fontFamily="Geist, sans-serif" fontSize="11" fontWeight="600" fill="#94A3B8" letterSpacing="0.06em">DEVICES</text>

          {/* iOS device pills */}
          <rect x="80" y="304" width="110" height="32" rx="16" fill="#F1F5F9" stroke="#CBD5E1"/>
          <text x="135" y="324" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="12" fill="#334155">real iPhone</text>
          <rect x="210" y="304" width="110" height="32" rx="16" fill="#F1F5F9" stroke="#CBD5E1"/>
          <text x="265" y="324" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="12" fill="#334155">simulator</text>

          {/* Android device pills */}
          <rect x="400" y="304" width="110" height="32" rx="16" fill="#F1F5F9" stroke="#CBD5E1"/>
          <text x="455" y="324" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="12" fill="#334155">real Pixel</text>
          <rect x="530" y="304" width="110" height="32" rx="16" fill="#F1F5F9" stroke="#CBD5E1"/>
          <text x="585" y="324" textAnchor="middle" fontFamily="Geist, sans-serif" fontSize="12" fill="#334155">emulator</text>
        </svg>
      </div>

      <p style={dpStyles.p}>
        <strong>Host requirements.</strong> Android works from any host with the Android SDK (<code style={dpStyles.inlineCode}>adb</code>). iOS — including the Simulator — requires a <strong>macOS host</strong>: WebDriverAgent must be code-signed with an Apple developer cert, and the signing toolchain is macOS-only.
      </p>

      <h2 id="example" style={dpStyles.h2}>What it would look like</h2>
      <p style={dpStyles.p}>
        Same lazy auto-waiting locator pattern as the web API. <code style={dpStyles.inlineCode}>launch_ios()</code> handles WDA install + port-forward; you get a session and a familiar <code style={dpStyles.inlineCode}>Locator</code> with platform-aware selectors.
      </p>
      <CodeBlock lang="vlang" filename="example_mobile.v" lines={[
        [{ t: "import", k: "keyword" }, { t: " vebidor.mobile" }],
        [{ t: "" }],
        [{ t: "fn", k: "keyword" }, { t: " " }, { t: "main", k: "function" }, { t: "() {" }],
        [{ t: "  mut", k: "keyword" }, { t: " b := mobile." }, { t: "launch_ios", k: "function" }, { t: "(mobile." }, { t: "iOSOptions", k: "type" }, { t: "{" }],
        [{ t: "    udid:        " }, { t: "'00008110-001A1D2E0E80801E'", k: "string" }],
        [{ t: "    bundle_id:   " }, { t: "'com.foo.MyApp'", k: "string" }],
        [{ t: "    app_path:    " }, { t: "'/path/to/MyApp.ipa'", k: "string" }],
        [{ t: "    install_app: " }, { t: "true", k: "keyword" }],
        [{ t: "  })!" }],
        [{ t: "  defer", k: "keyword" }, { t: " { b." }, { t: "close", k: "function" }, { t: "() }" }],
        [{ t: "" }],
        [{ t: "  ", k: null }, { t: "// auto-waiting locator — same as web", k: "comment" }],
        [{ t: "  b." }, { t: "get_by_label", k: "function" }, { t: "(" }, { t: "'Sign in'", k: "string" }, { t: ")." }, { t: "tap", k: "function" }, { t: "()!" }],
        [{ t: "  b." }, { t: "get_by_label", k: "function" }, { t: "(" }, { t: "'Email'", k: "string" }, { t: ")." }, { t: "fill", k: "function" }, { t: "(" }, { t: "'me@example.com'", k: "string" }, { t: ")!" }],
        [{ t: "" }],
        [{ t: "  ", k: null }, { t: "// pointer batch → one round trip; assertion is a separate read", k: "comment" }],
        [{ t: "  b." }, { t: "flow", k: "function" }, { t: "([" }],
        [{ t: "    .tap_text(" }, { t: "'Continue'", k: "string" }, { t: ")," }],
        [{ t: "    .assert_visible(" }, { t: "'Welcome back'", k: "string" }, { t: "),", k: null }],
        [{ t: "  ])!" }],
        [{ t: "}" }],
      ]} />

      <h2 id="speed-targets" style={dpStyles.h2}>Speed targets</h2>
      <p style={dpStyles.p}>
        Projected, not measured. The "fastest" column stays out of reach — Espresso runs inside the app process and Vebidor can't.
      </p>
      <ComparisonTable
        columns={[
          { label: "Operation", width: "32%" },
          { label: "Appium", width: "18%" },
          { label: "Maestro", width: "18%" },
          { label: "Vebidor mobile (proj.)", width: "20%" },
          { label: "In-process (Espresso)" },
        ]}
        rows={[
          ["Single tap command",      "100–300 ms", "30–80 ms",    { chip: "15–40 ms",   kind: "success", em: "✨" }, "1–5 ms"],
          ["Session start (real)",    "15–60 s",    "5–15 s",      { chip: "3–10 s",     kind: "success", em: "✨" }, "n/a (already in app)"],
          ["Batched pointer flow · 10 taps", "1–3 s",      "300–800 ms",  { chip: "100–300 ms", kind: "success", em: "✨" }, "10–30 ms"],
        ]}
      />

      <Callout kind="milestone" title="The honest framing">
        <p style={{ margin: 0 }}>
          Out-of-process, the win comes from <strong>removing the Node hop</strong> and <strong>batching at the protocol layer</strong>. V's overhead is below Node's, but the latency floor is still set by USB / WiFi to the device. In-process tooling will always win raw command speed; Vebidor's claim is "the fastest universal out-of-process mobile runner."
        </p>
      </Callout>

      <h2 id="mvp" style={dpStyles.h2}>What shipped</h2>
      <ol style={{ ...dpStyles.ul, paddingLeft: 24 }}>
        <li style={dpStyles.li}><strong>mobile/wda.v</strong> — V client for WebDriverAgent's endpoints (reuses the existing <code style={dpStyles.inlineCode}>HttpTransport</code>).</li>
        <li style={dpStyles.li}><strong>mobile/uia2.v</strong> — V client for the UiAutomator2 server.</li>
        <li style={dpStyles.li}><strong>mobile/locator.v</strong> + <strong>selectors.v</strong> — lazy auto-waiting <code style={dpStyles.inlineCode}>MobileLocator</code> and cross-platform <code style={dpStyles.inlineCode}>get_by_*</code> selectors, same semantics as web.</li>
        <li style={dpStyles.li}><strong>mobile/wda_bridge.v</strong> / <strong>uia2_bridge.v</strong> — wrap <code style={dpStyles.inlineCode}>xcodebuild</code>/<code style={dpStyles.inlineCode}>go-ios</code>/<code style={dpStyles.inlineCode}>adb</code> lifecycle behind a <code style={dpStyles.inlineCode}>launch_ios()</code> / <code style={dpStyles.inlineCode}>launch_android()</code> API.</li>
        <li style={dpStyles.li}><strong>mobile/assertions.v</strong>, <strong>gestures.v</strong>, <strong>app.v</strong>, <strong>device.v</strong>, <strong>device_state.v</strong> — <code style={dpStyles.inlineCode}>expect()</code>, touch gestures, app lifecycle, and device state.</li>
        <li style={dpStyles.li}><strong>examples/mobile/</strong> — iOS + Android smoke tests, cross-platform selectors, assertions, app/device state. Verified live on emulator/Simulator.</li>
      </ol>

      <h2 id="skip" style={dpStyles.h2}>Out of scope</h2>
      <ul style={dpStyles.ul}>
        <li style={dpStyles.li}><strong>In-process V on iOS/Android.</strong> V compiles to ARM and can link as a <code style={dpStyles.inlineCode}>.dylib</code>/<code style={dpStyles.inlineCode}>.so</code>, but everything useful (UIKit, AndroidX) sits behind a Swift/Kotlin FFI boundary that erases the in-process speed advantage. Use XCTest/Espresso natively if you need that tier.</li>
        <li style={dpStyles.li}><strong>Beating Detox on React Native.</strong> Detox understands RN's bridge and Hermes idle signals. Reproducing that in V means tracking React Native's release cadence forever. Not worth it.</li>
        <li style={dpStyles.li}><strong>Native app element trees beyond what WDA/UiAutomator2 expose.</strong> Vebidor's reach stops where its backend's reach stops — no private API spelunking.</li>
      </ul>
    </article>
  );
}

const archStyles = {
  frame: {
    border: "1px solid var(--border-1)",
    borderRadius: "var(--radius-lg)",
    background: "var(--surface-0)",
    padding: 20,
    margin: "20px 0",
  },
};

// ───────── PAGE: Changelog ─────────
const RELEASES = [
  {
    v: "4.2.0", date: "2026-05-26", title: "Mobile emulation",
    chip: { kind: "info", em: "✨", label: "Latest" },
    blurb: "Playwright-style mobile-web emulation over BiDi — browser-side, not Appium. Verified live against headless Edge.",
    sections: [
      { kind: "added", items: [
        "Device descriptor + emulate(ctx, device) — viewport + DPR + preload UA/touch overrides",
        "9 device presets (iPhone SE/12/14/14 Pro Max, Pixel 5/7, Galaxy S21, iPad, iPad Mini)",
        "Touch input via Actions API + Locator.tap()",
        "Server-side User-Agent rewrite via interception",
        "Locale / timezone / orientation via the BiDi emulation module",
      ]},
      { kind: "limit", items: [
        "Real touch-event dispatch (touchstart/touchend) needs CDP/mobileEmulation — BiDi doesn't expose it. tap() synthesizes a click.",
      ]},
    ],
  },
  {
    v: "4.1.0", date: "2026-05-25", title: "Per-context conveniences + capability probing",
    chip: { kind: "info", em: "✨", label: "Feature" },
    blurb: "Closes the two vs-Playwright gaps around user contexts — leanness (now has the conveniences) and maturity (now probeable rather than assumed).",
    sections: [
      { kind: "added", items: [
        "storageState + apply_storage_state + add_cookies (session reuse across user contexts)",
        "UserContextOptions: per-context proxy + accept_insecure_certs",
        "set_geolocation, set_permission",
        "status() and supports(method, params) for feature-detecting BiDi modules",
      ]},
    ],
  },
  {
    v: "4.0.1", date: "2026-05-25", title: "Partition-aware BiDi cookies + inline event dispatch",
    chip: { kind: "danger", em: "🐛", label: "Patch" },
    blurb: "Partition-scoped storage operations and a lower-overhead event handler for high-frequency observers.",
    sections: [
      { kind: "added", items: [
        "Optional CookiePartition on get_cookies / set_cookie / delete_cookies — scoped by user_context or context",
        "on_sync(event, handler) — inline dispatch on the listener thread (no thread spawn)",
      ]},
      { kind: "fixed", items: [
        "README + examples — corrected `import vebidor { webdriver }` (broken syntax) → `import vebidor.webdriver`",
      ]},
    ],
  },
  {
    v: "4.0.0", date: "2026-05-24", title: "Playwright-style API + WebDriver-BiDi",
    chip: { kind: "milestone", em: "🎭", label: "Major release" },
    blurb: "Playwright-style ergonomic layer and a WebDriver-BiDi (WebSocket) transport on top of the existing Classic client. Additive — no breaking changes.",
    sections: [
      { kind: "added", items: [
        "Lazy auto-waiting Locator (re-resolves on each use, staleness-immune)",
        "Selector engines: get_by_role / get_by_text / get_by_label / get_by_placeholder / get_by_test_id",
        "Web-first assertions: expect(loc).to_be_visible() with .not() and .with_timeout(ms)",
        "launch() / launch_edge / launch_chrome / launch_firefox / launch_safari lifecycle",
        "BiDi core: WebSocket client, browsingContext / script / log modules",
        "BiDi network: route + fulfill / abort / continue, route_response, on_auth, on_request, on_response",
        "BiDi contexts: create_user_context, set_viewport, print_pdf, traverse_history, activate",
        "BiDi storage: get_cookies / set_cookie / delete_cookies + on_cookie_changed",
        "BiDi DOM: locate_nodes + set_files (file upload)",
        "BiDi screenshots + Tracer (JSON activity log)",
      ]},
      { kind: "fixed", items: [
        "screenshot() / element_screenshot() — now use W3C GET endpoints (previously POST, which EdgeDriver rejected)",
      ]},
      { kind: "changed", items: [
        "WebDriver gained a Transport seam so Classic-HTTP and BiDi-WebSocket coexist behind one type. WebDriver is now @[heap] so Locator can reference it.",
      ]},
    ],
  },
  {
    v: "3.1.1", date: "2026-02-15", title: "Multi-Browser Bug Fixes",
    chip: { kind: "danger", em: "🐛", label: "Patch" },
    blurb: "Fixed compilation + runtime errors in v3.1.0 multi-browser support. Standardized parameter naming across all drivers.",
    sections: [
      { kind: "fixed", items: [
        "COMPILE ERROR — created new_session() helper in client.v (chrome/firefox/safari were calling undefined function)",
        "RUNTIME — corrected Safari W3C JSON tag from 'safari:automaticInspection' to 'safari:options'",
        "Consistency — moved new_edge_driver() to edge.v to match the other browser drivers",
        "Standardized parameter `url` → `base_url` across all driver constructors",
        "Added webdriver/multi_browser_test.v with 10 compilation tests",
      ]},
    ],
  },
  {
    v: "3.1.0", date: "2026-02-15", title: "Multi-Browser Support",
    chip: { kind: "info", em: "🌐", label: "Feature" },
    blurb: "Added Chrome, Firefox, and Safari support in addition to existing Edge. One API, four browsers, W3C-compliant.",
    sections: [
      { kind: "added", items: [
        "new_chrome_driver — default ChromeDriver endpoint http://127.0.0.1:9515",
        "new_firefox_driver — default GeckoDriver endpoint http://127.0.0.1:4444",
        "new_safari_driver — default SafariDriver endpoint http://127.0.0.1:4445",
        "ChromeOptions / FirefoxOptions / SafariOptions capability structs",
      ]},
    ],
  },
  {
    v: "3.0.0", date: "2026-02-15", title: "Phase 8 Complete — 100% Feature Parity Achieved",
    chip: { kind: "milestone", em: "🏆", label: "Milestone" },
    blurb: "Phase 8: async JavaScript execution + Shadow DOM. Selenium feature coverage hits 100%. 40 methods added across all 8 phases (55% → 100%).",
    sections: [
      { kind: "added", items: [
        "execute_async_script — async JS with callback / Promise / async-await support",
        "get_shadow_root — access an element's shadow DOM",
        "find_element_in_shadow_root + find_elements_in_shadow_root",
        "ShadowRoot struct",
      ]},
      { kind: "milestone", items: [
        "55% → 100% Selenium feature parity",
        "Shadow DOM: 0% → 100%",
        "JavaScript execution: 67% → 100%",
      ]},
    ],
  },
  {
    v: "2.3.0", date: "2026-02-15", title: "Phase 5 Complete — 98% Feature Parity",
    chip: { kind: "success", em: "✅", label: "Phase 5" },
    blurb: "CSS property values complete the Element Properties category. All 9 Selenium element property methods now natively supported.",
    sections: [
      { kind: "added", items: [
        "get_css_value(el, property_name) — returns computed values (rgba, px, etc.), not specified values",
      ]},
    ],
  },
  {
    v: "2.2.0", date: "2026-02-15", title: "Phase 7 Complete — 97% Feature Parity",
    chip: { kind: "success", em: "✅", label: "Phase 7" },
    blurb: "Advanced actions: context click, drag-and-drop variants, click-and-hold/release, element rect, form submit. Actions API and Element Interaction now 100%.",
    sections: [
      { kind: "added", items: [
        "context_click (right-click) + click_and_hold + release_held_button",
        "drag_and_drop_to_element + drag_and_drop_by_offset",
        "get_element_rect — returns x/y/width/height in pixels",
        "submit(el) — form submission shortcut",
        "ElementRect struct",
      ]},
    ],
  },
  {
    v: "2.1.0", date: "2026-02-15", title: "Phase 6 Complete — 91% Feature Parity",
    chip: { kind: "success", em: "✅", label: "Phase 6" },
    blurb: "Expected conditions and advanced waits. Selenium's most-used wait patterns now available in V. Timeouts/Waits 14% → 100%.",
    sections: [
      { kind: "added", items: [
        "wait_until_clickable + wait_until_visible + wait_until_present",
        "wait_for_text_in_element — substring match",
        "get_timeouts() — retrieve current implicit / page_load / script timeouts",
        "500ms polling interval, timeout errors include selector + duration",
      ]},
    ],
  },
  {
    v: "2.0.0", date: "2026-02-14", title: "Phase 4 Complete — 85% Feature Parity",
    chip: { kind: "success", em: "🎉", label: "Phase 4" },
    blurb: "All 4 originally-planned phases complete. Window management 56% → 100%. 23 methods added across phases 1-4.",
    sections: [
      { kind: "added", items: [
        "switch_to_window + new_window (tab or window) + maximize / minimize / fullscreen",
        "set_implicit_wait + set_page_load_timeout + set_script_timeout",
      ]},
    ],
  },
  {
    v: "1.10.0", date: "2026-02-14", title: "Phase 3 Complete — Page Information",
    chip: { kind: "success", em: "✅", label: "Phase 3" },
    blurb: "Page information methods: title, URL, and HTML source. Page Information 0% → 100%.",
    sections: [
      { kind: "added", items: [
        "get_title — current page title",
        "get_current_url — current page URL",
        "get_page_source — HTML source",
      ]},
    ],
  },
  {
    v: "1.00.0", date: "2026-02-14", title: "Phase 2 Complete — Alert Handling",
    chip: { kind: "success", em: "✅", label: "Phase 2" },
    blurb: "Complete support for alert(), confirm(), and prompt() dialogs. Alert Handling 0% → 100%.",
    sections: [
      { kind: "added", items: [
        "accept_alert — accept alert/confirm/prompt",
        "dismiss_alert — dismiss/cancel",
        "get_alert_text — read dialog message",
        "send_alert_text — send input to a prompt dialog",
      ]},
    ],
  },
  {
    v: "0.95.0", date: "2026-02-14", title: "Phase 1 Complete — Element Properties",
    chip: { kind: "success", em: "✅", label: "Phase 1" },
    blurb: "8 element property methods used by ~90% of automation scripts. No more JavaScript workarounds for element inspection.",
    sections: [
      { kind: "added", items: [
        "get_text + get_attribute + get_property + get_tag_name",
        "is_displayed + is_enabled + is_selected",
        "clear — empty an input or textarea",
      ]},
    ],
  },
  {
    v: "0.90.0", date: "2026-02-14", title: "Initial Bug Fixes",
    chip: { kind: "danger", em: "🐛", label: "Patch" },
    blurb: "W3C protocol compliance, JSON encoding, session lifecycle. The pre-Phase-1 foundation pass.",
    sections: [
      { kind: "fixed", items: [
        "Window + cookie methods — switched POST → GET to comply with W3C",
        "Deprecated json.raw_decode() → json.decode[json.Any]()",
        "JSON double-encoding (struct → JSON → JSON) — now builds map[string]json.Any directly",
        "Empty firstMatch array rejected by EdgeDriver — made optional",
        "Browser name 'edge' → 'msedge' (W3C standard)",
      ]},
      { kind: "added", items: [
        "WebDriver.quit() — proper session cleanup",
        "Content-Type: application/json header on all POSTs",
      ]},
    ],
  },
];

function PageChangelog() {
  return (
    <article style={dpStyles.page}>
      <div style={dpStyles.breadcrumb}>Reference <span style={{ margin: "0 6px", color: "var(--fg-4)" }}>/</span> <span style={dpStyles.breadcrumb_b}>Changelog</span></div>
      <h1 id="changelog" style={dpStyles.h1}>Changelog</h1>
      <p style={dpStyles.lede}>
        Every release closes a specific gap — usually relative to Selenium or Playwright. Versions are organized around <strong>Phases</strong>: each phase is a feature cluster that pushes Selenium parity from 55% toward 100%, then layers Playwright ergonomics on top.
      </p>

      <Callout kind="milestone" title="Where we are now">
        <p style={{ margin: 0 }}>
          <strong>v4.2.0</strong> · <span className="emoji">🏆</span> 100% Selenium parity since v3.0.0 · Playwright-style API + WebDriver-BiDi since v4.0.0 · mobile-web emulation since v4.2.0. Latest features verified live against headless Edge.
        </p>
      </Callout>

      <div style={clStyles.timeline}>
        {RELEASES.map((r, i) => (
          <div key={i} style={clStyles.row}>
            <div style={clStyles.rail}>
              <div style={clStyles.tick} />
              <div style={{ ...clStyles.dot, ...(r.chip.kind === "milestone" ? clStyles.dotMilestone : {}) }} />
            </div>
            <div style={clStyles.card}>
              <div style={clStyles.head}>
                <code style={clStyles.version}>v{r.v}</code>
                <span className={`chip chip--${r.chip.kind}`} style={{ fontSize: 11 }}>
                  <span className="emoji">{r.chip.em}</span> {r.chip.label}
                </span>
                <span style={clStyles.date}>{r.date}</span>
              </div>
              <h3 style={clStyles.title}>{r.title}</h3>
              <p style={clStyles.blurb}>{r.blurb}</p>
              {r.sections.map((s, j) => (
                <div key={j} style={clStyles.section}>
                  <div style={{ ...clStyles.sectionLabel, ...sectionLabelColor(s.kind) }}>
                    <span className="emoji" style={{ fontSize: 12 }}>{sectionEm(s.kind)}</span>
                    {sectionLabel(s.kind)}
                  </div>
                  <ul style={clStyles.list}>
                    {s.items.map((it, k) => (
                      <li key={k} style={clStyles.li}>{it}</li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div style={clStyles.footer}>
        <p style={{ ...dpStyles.p, margin: 0 }}>
          <strong>Looking for the raw file?</strong> The full <code style={dpStyles.inlineCode}>CHANGELOG.md</code> (50 KB, ~1300 lines with every test list and full code example) lives on GitHub:
        </p>
        <a href="https://github.com/quaesitor-scientiam/vebidor/blob/main/CHANGELOG.md" style={clStyles.linkBtn}>
          <span className="emoji" style={{ fontSize: 14 }}>📖</span>
          View CHANGELOG.md on GitHub
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ marginLeft: 4 }}>
            <path d="M7 17 17 7"/><path d="M7 7h10v10"/>
          </svg>
        </a>
      </div>
    </article>
  );
}

function sectionEm(kind) {
  return { added: "✨", fixed: "🐛", changed: "🔧", limit: "⚠️", milestone: "🏆" }[kind] || "✅";
}
function sectionLabel(kind) {
  return { added: "Added", fixed: "Fixed", changed: "Changed", limit: "Not implemented", milestone: "Milestone" }[kind] || "Changes";
}
function sectionLabelColor(kind) {
  const c = { added: "var(--info-fg)", fixed: "var(--danger-fg)", changed: "var(--fg-2)", limit: "var(--warning-fg)", milestone: "var(--milestone-fg)" }[kind];
  return c ? { color: c } : {};
}

const clStyles = {
  timeline: { display: "flex", flexDirection: "column", gap: 16, marginTop: 28 },
  row: { display: "grid", gridTemplateColumns: "44px 1fr", gap: 16 },
  rail: { position: "relative", display: "flex", justifyContent: "center" },
  tick: { position: "absolute", top: 0, bottom: -16, left: "50%", transform: "translateX(-50%)", width: 2, background: "var(--border-2)" },
  dot: { width: 12, height: 12, borderRadius: 12, background: "var(--vb-blue-500)", border: "3px solid #fff", boxShadow: "0 0 0 1px var(--vb-blue-300)", marginTop: 10, position: "relative", zIndex: 1 },
  dotMilestone: { background: "var(--milestone-line)", boxShadow: "0 0 0 1px rgba(212,160,23,0.4)" },
  card: { border: "1px solid var(--border-1)", borderRadius: "var(--radius-lg)", padding: 18, background: "#fff" },
  head: { display: "flex", alignItems: "center", gap: 10, marginBottom: 8, flexWrap: "wrap" },
  version: { fontFamily: "var(--font-mono)", fontSize: 12, fontWeight: 700, color: "var(--fg-1)", background: "var(--surface-2)", padding: "3px 8px", borderRadius: 5, border: "1px solid var(--border-1)", letterSpacing: "0.01em" },
  date: { fontFamily: "var(--font-mono)", fontSize: 11.5, color: "var(--fg-3)", marginLeft: "auto" },
  title: { fontFamily: "var(--font-sans)", fontSize: 18, fontWeight: 600, margin: "0 0 6px", color: "var(--fg-1)", letterSpacing: "-0.01em" },
  blurb: { fontFamily: "var(--font-sans)", fontSize: 14, lineHeight: 1.55, color: "var(--fg-2)", margin: "0 0 14px" },
  section: { marginBottom: 12 },
  sectionLabel: { display: "flex", alignItems: "center", gap: 6, fontFamily: "var(--font-sans)", fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.06em", marginBottom: 6 },
  list: { margin: 0, paddingLeft: 22, fontFamily: "var(--font-sans)", fontSize: 13.5, lineHeight: 1.55, color: "var(--fg-1)" },
  li: { marginBottom: 3 },
  footer: { marginTop: 40, paddingTop: 24, borderTop: "1px solid var(--border-1)" },
  linkBtn: { display: "inline-flex", alignItems: "center", gap: 8, marginTop: 12, padding: "10px 16px", background: "var(--surface-1)", border: "1px solid var(--border-2)", borderRadius: "var(--radius-sm)", color: "var(--fg-1)", fontFamily: "var(--font-sans)", fontSize: 14, fontWeight: 500, textDecoration: "none" },
};

const PAGES_DATA = {
  "quick-start": { component: PageQuickStart, toc: [
    { id: "quick-start", label: "Quick start", depth: 1 },
    { id: "install", label: "Install", depth: 2 },
    { id: "first-script", label: "Your first script", depth: 2 },
    { id: "run", label: "Run it", depth: 2 },
    { id: "next", label: "Next steps", depth: 2 },
  ]},
  "modern-api": { component: PageModernApi, toc: [
    { id: "modern-api", label: "Modern API", depth: 1 },
    { id: "locators", label: "Locators", depth: 2 },
    { id: "actions", label: "Auto-waiting actions", depth: 2 },
    { id: "assertions", label: "Web-first assertions", depth: 2 },
  ]},
  "bidi": { component: PageBiDi, toc: [
    { id: "bidi", label: "WebDriver-BiDi", depth: 1 },
    { id: "network-mocking", label: "Network mocking", depth: 2 },
    { id: "contexts", label: "Isolated contexts", depth: 2 },
  ]},
  "mobile": { component: PageMobile, toc: [
    { id: "mobile", label: "Mobile (preview)", depth: 1 },
    { id: "speed-comes-from", label: "Where speed comes from", depth: 2 },
    { id: "architecture", label: "Architecture", depth: 2 },
    { id: "example", label: "What it would look like", depth: 2 },
    { id: "speed-targets", label: "Speed targets", depth: 2 },
    { id: "mvp", label: "MVP plan", depth: 2 },
    { id: "skip", label: "Out of scope", depth: 2 },
  ]},
  "comparison": { component: PageComparison, toc: [
    { id: "comparison", label: "Comparison", depth: 1 },
    { id: "vs-playwright", label: "vs Playwright", depth: 2 },
    { id: "phases", label: "Phase history", depth: 2 },
  ]},
  "changelog": { component: PageChangelog, toc: [
    { id: "changelog", label: "Changelog", depth: 1 },
  ]},
};

function DocsPage({ pageId, onNavigate }) {
  const data = PAGES_DATA[pageId] || PAGES_DATA["quick-start"];
  const Page = data.component;
  return <Page onNavigate={onNavigate} />;
}

window.DocsPage = DocsPage;
window.DOCS_PAGES_TOC = (id) => (PAGES_DATA[id] || PAGES_DATA["quick-start"]).toc;
