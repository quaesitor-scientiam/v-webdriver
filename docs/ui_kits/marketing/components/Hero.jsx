/* global React */
function Hero() {
  return (
    <section style={heroStyles.section}>
      <div style={heroStyles.glow} aria-hidden="true" />
      <div className="mk-container" style={heroStyles.grid}>
        <div style={heroStyles.text}>
          <div style={heroStyles.eyebrow}>
            <span className="chip chip--milestone"><span className="emoji">🏆</span> 100% Selenium parity</span>
            <span style={heroStyles.eyebrowDot}>·</span>
            <span style={heroStyles.eyebrowMuted}>v5.0.0 · 2026-06-02</span>
          </div>
          <h1 style={heroStyles.h1}>Playwright-style<br />browser <span style={heroStyles.h1Accent}>+ mobile</span><br />automation, <span style={heroStyles.h1Accent}>natively in V</span>.</h1>
          <p style={heroStyles.lede}>
            A W3C WebDriver + WebDriver-BiDi client with lazy auto-waiting Locators, semantic
            selector engines, web-first assertions, network mocking, and one-call <code style={heroStyles.code}>launch()</code> —
            and as of v5.0.0, <strong>native iOS &amp; Android</strong> driving over WebDriverAgent and
            UiAutomator2. Verified live against headless Edge.
          </p>
          <div style={heroStyles.install}>
            <span style={heroStyles.installPrompt}>$</span>
            <code style={heroStyles.installCode}>v install vebidor</code>
          </div>
          <div style={heroStyles.ctas}>
            <a href="../docs/index.html" style={heroStyles.ctaPrimary}>
              <span className="emoji" style={{ fontSize: 14 }}>🚀</span> Quick start
            </a>
            <a href="#features" style={heroStyles.ctaSecondary}>See features</a>
            <a href="https://github.com/quaesitor-scientiam/vebidor" style={heroStyles.ctaGhost}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" style={{ marginRight: 6 }}><path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.1.79-.25.79-.56v-1.98c-3.2.7-3.87-1.54-3.87-1.54-.52-1.34-1.28-1.7-1.28-1.7-1.05-.71.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.71 1.26 3.37.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.68 0-1.26.45-2.28 1.19-3.08-.12-.29-.51-1.46.11-3.05 0 0 .97-.31 3.18 1.18a11 11 0 0 1 5.79 0c2.21-1.49 3.18-1.18 3.18-1.18.62 1.59.23 2.76.11 3.05.74.8 1.19 1.82 1.19 3.08 0 4.41-2.69 5.38-5.26 5.67.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.55 4.56-1.53 7.85-5.83 7.85-10.91C23.5 5.65 18.35.5 12 .5Z"/></svg>
              GitHub
            </a>
          </div>
          <div style={heroStyles.metaRow}>
            <div style={heroStyles.metaItem}><strong>4</strong> browsers</div>
            <div style={heroStyles.metaDot}>·</div>
            <div style={heroStyles.metaItem}><strong>40+</strong> methods added</div>
            <div style={heroStyles.metaDot}>·</div>
            <div style={heroStyles.metaItem}><strong>0</strong> dependencies</div>
            <div style={heroStyles.metaDot}>·</div>
            <div style={heroStyles.metaItem}>MIT</div>
          </div>
        </div>
        <div style={heroStyles.codeCol}>
          <div style={heroStyles.codeFrame}>
            <div style={heroStyles.codeHead}>
              <div style={heroStyles.codeDots}>
                <span style={{ ...heroStyles.dot, background: "#FF5F57" }}></span>
                <span style={{ ...heroStyles.dot, background: "#FEBC2E" }}></span>
                <span style={{ ...heroStyles.dot, background: "#27C840" }}></span>
              </div>
              <span style={heroStyles.codeLang}>example_modern.v</span>
              <span style={{ width: 36 }} />
            </div>
            <pre style={heroStyles.pre}>
              <code>
                <div><span style={tk("keyword")}>import</span> vebidor.webdriver</div>
                <div>&nbsp;</div>
                <div><span style={tk("keyword")}>fn</span> <span style={tk("function")}>main</span>() {`{`}</div>
                <div>{`  `}<span style={tk("comment")}>// auto-detects driver, picks free port</span></div>
                <div>{`  `}<span style={tk("keyword")}>mut</span> b := webdriver.<span style={tk("function")}>launch_edge</span>(webdriver.<span style={tk("type")}>LaunchOptions</span>{`{`}</div>
                <div>{`    `}headless: <span style={tk("keyword")}>true</span>, bidi: <span style={tk("keyword")}>true</span></div>
                <div>{`  `}{`}`})!</div>
                <div>{`  `}<span style={tk("keyword")}>defer</span> {`{`} b.<span style={tk("function")}>close</span>() {`}`}</div>
                <div>&nbsp;</div>
                <div>{`  `}b.<span style={tk("function")}>goto</span>(<span style={tk("string")}>'https://example.com'</span>)!</div>
                <div>&nbsp;</div>
                <div>{`  `}<span style={tk("comment")}>// lazy, auto-waiting, retries until visible</span></div>
                <div>{`  `}webdriver.<span style={tk("function")}>expect</span>(</div>
                <div>{`    `}b.wd.<span style={tk("function")}>get_by_role</span>(<span style={tk("string")}>'heading'</span>, <span style={tk("string")}>''</span>)</div>
                <div>{`  `}).<span style={tk("function")}>to_be_visible</span>()!</div>
                <div>{`}`}</div>
              </code>
            </pre>
          </div>
        </div>
      </div>
    </section>
  );
}

function tk(k) {
  return {
    keyword:  { color: "var(--code-keyword)" },
    string:   { color: "var(--code-string)" },
    number:   { color: "var(--code-number)" },
    function: { color: "var(--code-function)" },
    type:     { color: "var(--code-type)" },
    comment:  { color: "var(--code-comment)", fontStyle: "italic" },
  }[k];
}

const heroStyles = {
  section: { padding: "80px 0 100px", position: "relative", overflow: "hidden" },
  glow: { position: "absolute", top: -200, left: "50%", transform: "translateX(-50%)", width: 900, height: 600, background: "radial-gradient(circle at center, rgba(62,99,221,0.07), transparent 60%)", pointerEvents: "none", zIndex: 0 },
  grid: { position: "relative", zIndex: 1, display: "grid", gridTemplateColumns: "minmax(0,1fr) minmax(0,1.05fr)", gap: 56, alignItems: "center" },
  text: { maxWidth: 540 },
  eyebrow: { display: "flex", alignItems: "center", gap: 10, marginBottom: 24 },
  eyebrowDot: { color: "var(--fg-4)" },
  eyebrowMuted: { fontFamily: "var(--font-mono)", fontSize: 11.5, color: "var(--fg-3)" },
  h1: { fontFamily: "var(--font-sans)", fontWeight: 800, fontSize: 56, lineHeight: 1.05, letterSpacing: "-0.03em", color: "var(--fg-1)", margin: "0 0 22px" },
  h1Accent: { color: "var(--vb-blue-500)" },
  lede: { fontFamily: "var(--font-sans)", fontSize: 19, lineHeight: 1.55, color: "var(--fg-2)", margin: "0 0 32px" },
  code: { fontFamily: "var(--font-mono)", fontSize: "0.9em", color: "var(--vb-blue-700)", background: "var(--vb-blue-50)", padding: "0.1em 0.4em", borderRadius: 4 },
  install: { display: "inline-flex", alignItems: "center", gap: 10, background: "var(--code-bg)", border: "1px solid var(--slate-800)", borderRadius: "var(--radius-sm)", padding: "10px 16px", margin: "0 0 28px" },
  installPrompt: { fontFamily: "var(--font-mono)", fontSize: 14, color: "var(--slate-400)", userSelect: "none" },
  installCode: { fontFamily: "var(--font-mono)", fontSize: 14, color: "var(--code-fg)", letterSpacing: "-0.01em" },
  ctas: { display: "flex", gap: 10, alignItems: "center", marginBottom: 28, flexWrap: "wrap" },
  ctaPrimary: { display: "inline-flex", alignItems: "center", gap: 8, background: "var(--vb-blue-500)", color: "#fff", padding: "12px 20px", borderRadius: "var(--radius-sm)", fontFamily: "var(--font-sans)", fontWeight: 600, fontSize: 15, border: 0 },
  ctaSecondary: { display: "inline-flex", alignItems: "center", background: "#fff", color: "var(--fg-1)", padding: "12px 20px", borderRadius: "var(--radius-sm)", fontFamily: "var(--font-sans)", fontWeight: 600, fontSize: 15, border: "1px solid var(--border-2)" },
  ctaGhost: { display: "inline-flex", alignItems: "center", padding: "12px 14px", color: "var(--fg-2)", fontFamily: "var(--font-sans)", fontSize: 14, fontWeight: 500, border: 0 },
  metaRow: { display: "flex", alignItems: "center", gap: 10, color: "var(--fg-3)", fontFamily: "var(--font-sans)", fontSize: 13.5 },
  metaItem: { color: "var(--fg-2)" },
  metaDot: { color: "var(--fg-4)" },
  codeCol: { minWidth: 0 },
  codeFrame: { background: "var(--code-bg)", borderRadius: 12, overflow: "hidden", border: "1px solid var(--slate-800)", boxShadow: "0 24px 60px rgba(11,18,32,0.18), 0 4px 16px rgba(11,18,32,0.06)" },
  codeHead: { display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px 16px", background: "var(--slate-900)", borderBottom: "1px solid var(--slate-800)" },
  codeDots: { display: "flex", gap: 6 },
  dot: { width: 11, height: 11, borderRadius: 11, display: "inline-block" },
  codeLang: { fontFamily: "var(--font-mono)", fontSize: 11.5, color: "var(--slate-400)" },
  pre: { margin: 0, padding: "16px 20px", fontFamily: "var(--font-mono)", fontSize: 13.5, lineHeight: 1.7, color: "var(--code-fg)", letterSpacing: "-0.01em", overflowX: "auto" },
};

window.Hero = Hero;
