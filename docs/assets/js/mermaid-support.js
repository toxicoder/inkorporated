(async function() {
  try {
    // Import Mermaid as an ES Module
    const { default: mermaid } = await import('https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs');

    mermaid.initialize({
      startOnLoad: false,
      theme: 'default'
    });

    // Run mermaid on .language-mermaid elements
    await mermaid.run({
      querySelector: '.language-mermaid',
    });
  } catch (error) {
    console.error("Failed to load or initialize Mermaid:", error);
  }
})();
