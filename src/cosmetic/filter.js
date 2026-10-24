(() => {
  "use strict";
  if (
    !/^https:\/\/outlook\.(office\.com|live\.com|office365\.com|cloud\.microsoft)$/.test(
      location.origin,
    ) ||
    !/^\/mail(?:\/|$)/.test(location.pathname)
  )
    return;
  if (globalThis.__outlookCosmeticFilter) {
    if (
      globalThis.__outlookCosmeticFilter.version === 2 &&
      document.getElementById("local-outlook-cosmetic-filter")
    )
      return globalThis.__outlookCosmeticFilter.stats();
    globalThis.__outlookCosmeticFilter.stop();
  }
  const marker = "data-local-outlook-ad-hidden";
  const iconSelector = 'img[src*="/ads-olk-icon.png"]';
  const cardSelector = `[data-testid="virtuoso-scroller"] > div > div:has(${iconSelector}):not([role="option"]):not(:has([role="option"]))`;
  const installedAtMs = performance.now();
  const installedBeforeAd = !document.querySelector(iconSelector);
  const installedDuring = document.readyState;
  let scans = 0;
  function cardFor(icon) {
    if (icon.closest('[role="option"]')) return null;
    const scroller = icon.closest('[data-testid="virtuoso-scroller"]');
    if (!scroller) return null;
    let card = icon,
      foundMessageBoundary = false;
    for (
      let parent = card.parentElement;
      parent && parent !== scroller;
      parent = card.parentElement
    ) {
      if (
        parent.matches('[role="option"]') ||
        parent.querySelector('[role="option"]')
      ) {
        foundMessageBoundary = true;
        break;
      }
      const r = parent.getBoundingClientRect();
      if (r.height > 240 || r.width > 900) break;
      card = parent;
    }
    if (
      !foundMessageBoundary ||
      card === icon ||
      card.querySelector('[role="option"]')
    )
      return null;
    return card;
  }
  const style = document.createElement("style");
  style.id = "local-outlook-cosmetic-filter";
  // Declarative CSS takes effect during style calculation, before the next paint.
  style.textContent = `${cardSelector}, [${marker}="true"] { display: none !important; }`;
  function mountStyle() {
    if (!style.isConnected)
      (document.head || document.documentElement)?.append(style);
  }
  mountStyle();
  function scan() {
    mountStyle();
    scans++;
    for (const card of document.querySelectorAll(`[${marker}]`)) {
      if (
        !card.querySelector(iconSelector) ||
        card.matches('[role="option"]') ||
        card.querySelector('[role="option"]')
      )
        card.removeAttribute(marker);
    }
    for (const icon of document.querySelectorAll(iconSelector)) {
      const card = cardFor(icon);
      if (card && card.getAttribute(marker) !== "true")
        card.setAttribute(marker, "true");
    }
  }
  function stats() {
    const options = [...document.querySelectorAll('[role="option"]')];
    const icons = [...document.querySelectorAll(iconSelector)];
    return {
      version: 2,
      scans,
      installedAtMs,
      installedBeforeAd,
      installedDuring,
      adCards: document.querySelectorAll(`${cardSelector}, [${marker}]`).length,
      visibleAdIcons: icons.filter((e) => e.getBoundingClientRect().height > 0)
        .length,
      messageRows: options.length,
      visibleMessageRows: options.filter(
        (e) => e.getBoundingClientRect().height > 0,
      ).length,
    };
  }
  // Mutation observers run before rendering; no delayed 80 ms hide operation.
  const observer = new MutationObserver(scan);
  observer.observe(document, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["src", "role"],
  });
  globalThis.__outlookCosmeticFilter = {
    version: 2,
    stats,
    stop() {
      observer.disconnect();
      style.remove();
      for (const e of document.querySelectorAll(`[${marker}]`))
        e.removeAttribute(marker);
      delete globalThis.__outlookCosmeticFilter;
    },
  };
  scan();
  return stats();
})();
