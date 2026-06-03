/* global React */
const REPO = "https://github.com/quaesitor-scientiam/vebidor";

function TopNav({ onNavigate, activeId }) {
  const docNav = (id) => (e) => { e.preventDefault(); onNavigate && onNavigate(id); };
  return (
    <div style={tnStyles.bar}>
      <div style={tnStyles.inner}>
        <div style={tnStyles.left}>
          <a href="../../index.html" style={tnStyles.brand}>
            <img src="../../assets/logo-vebidor.png" width="24" height="24" alt="vebidor" style={{ borderRadius: 5, display: "block" }} />
            <span style={tnStyles.wordmark}>vebidor</span>
            <span style={tnStyles.version}>v5.1.0</span>
          </a>
          <nav style={tnStyles.nav}>
            <a style={tnStyles.navLink} href="#quick-start" onClick={docNav("quick-start")}>Docs</a>
            <a style={{ ...tnStyles.navLink, ...tnStyles.navLinkMuted }} href="#modern-api" onClick={docNav("modern-api")}>API</a>
            <a style={{ ...tnStyles.navLink, ...tnStyles.navLinkMuted }} href={`${REPO}/tree/main/examples`}>Examples</a>
            <a style={{ ...tnStyles.navLink, ...tnStyles.navLinkMuted }} href="#changelog" onClick={docNav("changelog")}>Changelog</a>
          </nav>
        </div>
        <div style={tnStyles.right}>
          <div style={tnStyles.search}>
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
              <circle cx="11" cy="11" r="7" />
              <path d="m20 20-4-4" />
            </svg>
            <span style={tnStyles.searchText}>Search the API…</span>
            <span style={tnStyles.kbd}>⌘ K</span>
          </div>
          <a href="https://github.com/quaesitor-scientiam/vebidor" style={tnStyles.iconBtn} aria-label="GitHub">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.1.79-.25.79-.56v-1.98c-3.2.7-3.87-1.54-3.87-1.54-.52-1.34-1.28-1.7-1.28-1.7-1.05-.71.08-.7.08-.7 1.16.08 1.77 1.19 1.77 1.19 1.03 1.77 2.71 1.26 3.37.96.1-.75.4-1.26.73-1.55-2.55-.29-5.24-1.28-5.24-5.68 0-1.26.45-2.28 1.19-3.08-.12-.29-.51-1.46.11-3.05 0 0 .97-.31 3.18 1.18a11 11 0 0 1 5.79 0c2.21-1.49 3.18-1.18 3.18-1.18.62 1.59.23 2.76.11 3.05.74.8 1.19 1.82 1.19 3.08 0 4.41-2.69 5.38-5.26 5.67.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.55 4.56-1.53 7.85-5.83 7.85-10.91C23.5 5.65 18.35.5 12 .5Z"/></svg>
          </a>
          <button style={tnStyles.iconBtn} aria-label="Theme">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>
          </button>
        </div>
      </div>
    </div>
  );
}

const tnStyles = {
  bar: {
    position: "fixed",
    top: 0,
    left: 0,
    right: 0,
    height: "var(--topnav-height)",
    background: "rgba(255,255,255,0.78)",
    backdropFilter: "blur(8px)",
    WebkitBackdropFilter: "blur(8px)",
    borderBottom: "1px solid var(--border-1)",
    zIndex: 50,
  },
  inner: {
    maxWidth: "var(--container-docs)",
    height: "100%",
    margin: "0 auto",
    padding: "0 24px",
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    gap: 24,
  },
  left: { display: "flex", alignItems: "center", gap: 28 },
  brand: { display: "flex", alignItems: "center", gap: 8, color: "var(--fg-1)", border: 0 },
  wordmark: { fontFamily: "var(--font-sans)", fontWeight: 800, fontSize: 18, letterSpacing: "-0.03em", color: "var(--vb-blue-800)" },
  version: { fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-3)", background: "var(--surface-2)", padding: "2px 6px", borderRadius: 4 },
  nav: { display: "flex", gap: 20 },
  navLink: { fontFamily: "var(--font-sans)", fontSize: 14, fontWeight: 500, color: "var(--fg-1)", border: 0 },
  navLinkMuted: { color: "var(--fg-2)", fontWeight: 400 },
  right: { display: "flex", alignItems: "center", gap: 8 },
  search: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    width: 240,
    height: 32,
    padding: "0 10px",
    background: "var(--surface-1)",
    border: "1px solid var(--border-1)",
    borderRadius: "var(--radius-sm)",
    color: "var(--fg-3)",
    cursor: "text",
  },
  searchText: { fontFamily: "var(--font-sans)", fontSize: 13, flex: 1 },
  kbd: { fontFamily: "var(--font-mono)", fontSize: 10.5, color: "var(--fg-3)", background: "var(--surface-0)", padding: "2px 5px", border: "1px solid var(--border-1)", borderRadius: 3 },
  iconBtn: {
    width: 32, height: 32,
    display: "inline-flex", alignItems: "center", justifyContent: "center",
    background: "transparent", border: 0, borderRadius: "var(--radius-sm)", color: "var(--fg-2)",
    cursor: "pointer",
  },
};

window.TopNav = TopNav;
