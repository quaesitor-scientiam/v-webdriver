/* global React, ReactDOM, TopNav, Sidebar, TocPanel, DocsPage, DOCS_PAGES_TOC */
const { useState, useEffect } = React;

const PAGES = [
  { id: "quick-start", title: "Quick start",    section: "Getting started" },
  { id: "install",     title: "Installation",   section: "Getting started" },
  { id: "config",      title: "Configuration",  section: "Getting started" },
  { id: "modern-api",  title: "Modern API",     section: "API reference", chip: "new" },
  { id: "locators",    title: "Locators",       section: "API reference" },
  { id: "selectors",   title: "Selector engines",section: "API reference" },
  { id: "assertions",  title: "Assertions",     section: "API reference" },
  { id: "bidi",        title: "WebDriver-BiDi", section: "API reference" },
  { id: "mobile",      title: "Mobile",         section: "API reference", chip: "new" },
  { id: "comparison",  title: "Comparison",     section: "Reference" },
  { id: "changelog",   title: "Changelog",      section: "Reference" },
];

const VALID_IDS = new Set(PAGES.map((p) => p.id));

function pageFromHash() {
  const h = (window.location.hash || "").replace(/^#/, "");
  return VALID_IDS.has(h) ? h : "quick-start";
}

function App() {
  const [activeId, setActiveId] = useState(pageFromHash);

  useEffect(() => {
    const onHash = () => setActiveId(pageFromHash());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  const navigate = (id) => {
    if (!VALID_IDS.has(id)) return;
    if (window.location.hash !== `#${id}`) {
      window.history.replaceState(null, "", `#${id}`);
    }
    setActiveId(id);
    window.scrollTo({ top: 0, behavior: "instant" });
  };

  return (
    <>
      <TopNav onNavigate={navigate} activeId={activeId} />
      <div className="topnav-spacer" />
      <div className="shell">
        <Sidebar pages={PAGES} activeId={activeId} onSelect={navigate} />
        <main className="main">
          <DocsPage pageId={activeId} onNavigate={navigate} />
        </main>
        <div className="toc-col">
          <TocPanel items={DOCS_PAGES_TOC(activeId)} />
        </div>
      </div>
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
