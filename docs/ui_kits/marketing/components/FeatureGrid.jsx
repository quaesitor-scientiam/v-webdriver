/* global React */
function FeatureGrid() {
  return (
    <section id="features" className="mk-section">
      <div className="mk-container">
        <div style={fgStyles.head}>
          <div style={fgStyles.eyebrow}>What's in the box</div>
          <h2 style={fgStyles.h2}>Web and mobile. One library.</h2>
          <p style={fgStyles.sub}>WebDriver Classic (HTTP) for the command surface, WebDriver-BiDi (WebSocket) for the event-driven stuff, and native iOS/Android over WebDriverAgent + UiAutomator2 — all sharing one transport, locator, and assertion engine.</p>
        </div>
        <div style={fgStyles.grid}>
          {FEATURES.map((f, i) => (
            <div key={i} style={fgStyles.card}>
              <div style={fgStyles.icon}>{f.em}</div>
              <h3 style={fgStyles.cardTitle}>{f.title}</h3>
              <p style={fgStyles.cardBody}>{f.body}</p>
              {f.chip && <div style={{ marginTop: 12 }}><span className={`chip chip--${f.chipKind}`}>{f.chip}</span></div>}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

const FEATURES = [
  {
    em: "⚡",
    title: "Auto-waiting Locators",
    body: "Lazy, re-resolvable, staleness-immune. Actions wait for the element to be attached, visible, enabled, and scrolled into view — no manual sleeps.",
    chip: "Modern API",
    chipKind: "info",
  },
  {
    em: "🎯",
    title: "Web-first assertions",
    body: "expect(loc).to_be_visible() polls until the condition holds. Invertible with .not(), tunable via .with_timeout(ms).",
  },
  {
    em: "🎭",
    title: "Network interception",
    body: "Playwright-style route + fulfill / abort / continue over WebDriver-BiDi. Response-phase mocking, HTTP auth, console & network events.",
    chip: "BiDi only",
    chipKind: "milestone",
  },
  {
    em: "🌐",
    title: "Selector engines",
    body: "get_by_role · get_by_text · get_by_label · get_by_placeholder · get_by_test_id. Plus css= and xpath= for the raw escape hatch.",
  },
  {
    em: "📲",
    title: "Native iOS & Android",
    body: "vebidor.mobile drives real apps over WebDriverAgent (iOS) and UiAutomator2 (Android) — same get_by_* selectors, auto-waiting locators, expect(), taps, swipes, and app/device lifecycle. No Node hop.",
    chip: "✨ v5.0",
    chipKind: "info",
  },
  {
    em: "📱",
    title: "Mobile-web emulation",
    body: "9 device presets (iPhone, Pixel, Galaxy, iPad). Viewport, DPR, UA, isMobile, hasTouch. Per-context locale, timezone, geolocation, permissions.",
  },
  {
    em: "🚀",
    title: "One-call launch()",
    body: "Auto-detects driver and browser, picks a free port, opens a session, tears everything down on close(). launch_ios() / launch_android() do the same for devices.",
  },
];

const fgStyles = {
  head: { textAlign: "left", maxWidth: 720, marginBottom: 48 },
  eyebrow: { fontFamily: "var(--font-sans)", fontSize: 12, fontWeight: 600, color: "var(--vb-blue-600)", textTransform: "uppercase", letterSpacing: "0.08em", marginBottom: 10 },
  h2: { fontFamily: "var(--font-sans)", fontWeight: 700, fontSize: 40, lineHeight: 1.15, letterSpacing: "-0.025em", margin: "0 0 14px", color: "var(--fg-1)" },
  sub: { fontFamily: "var(--font-sans)", fontSize: 18, lineHeight: 1.55, color: "var(--fg-2)", margin: 0 },
  grid: { display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 20 },
  card: { background: "#fff", border: "1px solid var(--border-1)", borderRadius: "var(--radius-xl)", padding: 26 },
  icon: { fontFamily: "var(--font-emoji)", fontSize: 30, lineHeight: 1, marginBottom: 14 },
  cardTitle: { fontFamily: "var(--font-sans)", fontSize: 18, fontWeight: 600, margin: "0 0 8px", color: "var(--fg-1)", letterSpacing: "-0.01em" },
  cardBody: { fontFamily: "var(--font-sans)", fontSize: 14.5, lineHeight: 1.55, color: "var(--fg-2)", margin: 0 },
};

window.FeatureGrid = FeatureGrid;
