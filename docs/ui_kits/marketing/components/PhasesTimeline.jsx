/* global React */
function PhasesTimeline() {
  return (
    <section id="phases" className="mk-section">
      <div className="mk-container">
        <div style={ptStyles.head}>
          <div style={ptStyles.eyebrow}>Receipts</div>
          <h2 style={ptStyles.h2}>From 55% parity to web + native mobile.</h2>
          <p style={ptStyles.sub}>Every release closes a specific gap relative to Selenium, Playwright, or Appium. No marketing math — feature counts come from the changelog.</p>
        </div>
        <div style={ptStyles.timeline}>
          {PHASES.map((p, i) => (
            <div key={i} style={ptStyles.row}>
              <div style={ptStyles.left}>
                <div style={ptStyles.tick} />
                <div style={ptStyles.dot} data-final={p.final ? "1" : "0"} />
              </div>
              <div style={ptStyles.body}>
                <div style={ptStyles.rowHead}>
                  <span style={ptStyles.phaseLabel}>{p.phase}</span>
                  {p.chip && <span className={`chip chip--${p.chipKind}`}>{p.chip}</span>}
                  <span style={ptStyles.version}>v{p.version}</span>
                </div>
                <h3 style={ptStyles.title}>{p.title}</h3>
                <p style={ptStyles.desc}>{p.desc}</p>
                <div style={ptStyles.coverage}>
                  <div style={ptStyles.barTrack}>
                    <div style={{ ...ptStyles.barFill, width: `${p.coverage}%` }} />
                  </div>
                  <span style={ptStyles.coverageLabel}>{p.coverage}% Selenium coverage</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

const PHASES = [
  { phase: "Phase 1–4", version: "2.0.0", title: "Selenium catch-up",            desc: "Element properties, alerts, page information, window management, timeouts.", coverage: 85, chip: "23 methods", chipKind: "neutral" },
  { phase: "Phase 5–7", version: "2.3.0", title: "Polish + advanced actions",    desc: "CSS values, expected conditions, context-click, drag-and-drop, form submit, element rects.", coverage: 98, chip: "13 methods", chipKind: "neutral" },
  { phase: "Phase 8",   version: "3.0.0", title: "100% feature parity",           desc: "Async JS execution + Shadow DOM. Selenium coverage hits 100%.", coverage: 100, chip: "🏆 Milestone", chipKind: "milestone", final: true },
  { phase: "Playwright Phase 0–5", version: "4.0.0", title: "Modern ergonomics layer", desc: "Transport seam, lazy auto-waiting Locators, web-first assertions, launch(), full WebDriver-BiDi.", coverage: 100, chip: "✨ New layer", chipKind: "info" },
  { phase: "v4.1 → v4.2", version: "4.2.0", title: "Per-context + mobile emulation", desc: "storageState, per-context proxy/geo/permissions, capability probing, 9 device presets, viewport+UA+touch.", coverage: 100, chip: "Web", chipKind: "neutral" },
  { phase: "Mob 1–7", version: "5.0.0", title: "Native iOS + Android", desc: "vebidor.mobile: real-app driving over WebDriverAgent + UiAutomator2, cross-platform get_by_* selectors, gestures, expect() assertions, app + device lifecycle.", coverage: 100, chip: "📲 Latest", chipKind: "info", final: true },
];

const ptStyles = {
  head: { textAlign: "left", maxWidth: 720, marginBottom: 56 },
  eyebrow: { fontFamily: "var(--font-sans)", fontSize: 12, fontWeight: 600, color: "var(--vb-blue-600)", textTransform: "uppercase", letterSpacing: "0.08em", marginBottom: 10 },
  h2: { fontFamily: "var(--font-sans)", fontWeight: 700, fontSize: 36, lineHeight: 1.15, letterSpacing: "-0.025em", margin: "0 0 12px", color: "var(--fg-1)" },
  sub: { fontFamily: "var(--font-sans)", fontSize: 17, lineHeight: 1.55, color: "var(--fg-2)", margin: 0 },
  timeline: { position: "relative", display: "flex", flexDirection: "column", gap: 14 },
  row: { display: "grid", gridTemplateColumns: "44px 1fr", gap: 18, position: "relative" },
  left: { position: "relative", display: "flex", justifyContent: "center" },
  tick: { position: "absolute", top: 0, bottom: -14, left: "50%", transform: "translateX(-50%)", width: 2, background: "var(--border-2)" },
  dot: { width: 14, height: 14, borderRadius: 14, background: "var(--vb-blue-500)", border: "3px solid #fff", boxShadow: "0 0 0 1px var(--vb-blue-300)", marginTop: 8, position: "relative", zIndex: 1 },
  body: { border: "1px solid var(--border-1)", borderRadius: "var(--radius-lg)", padding: 18, background: "#fff" },
  rowHead: { display: "flex", alignItems: "center", gap: 10, marginBottom: 8, flexWrap: "wrap" },
  phaseLabel: { fontFamily: "var(--font-mono)", fontSize: 11, fontWeight: 600, color: "var(--fg-2)", background: "var(--surface-2)", padding: "3px 8px", borderRadius: 5, border: "1px solid var(--border-1)", letterSpacing: "0.02em" },
  version: { fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-3)", marginLeft: "auto" },
  title: { fontFamily: "var(--font-sans)", fontSize: 18, fontWeight: 600, margin: "0 0 6px", color: "var(--fg-1)", letterSpacing: "-0.01em" },
  desc: { fontFamily: "var(--font-sans)", fontSize: 14, lineHeight: 1.55, color: "var(--fg-2)", margin: "0 0 12px" },
  coverage: { display: "flex", alignItems: "center", gap: 12 },
  barTrack: { flex: 1, height: 6, background: "var(--surface-2)", borderRadius: 6, overflow: "hidden" },
  barFill: { height: "100%", background: "var(--vb-blue-500)", borderRadius: 6 },
  coverageLabel: { fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-3)", whiteSpace: "nowrap" },
};

window.PhasesTimeline = PhasesTimeline;
