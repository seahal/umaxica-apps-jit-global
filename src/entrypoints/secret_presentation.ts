// This document has no Inertia, Turbo, service worker registration or analytics entrypoint.
// Remove rendered values before a page can enter the browser's back/forward cache.
function clearPresentedValues() {
  for (const node of document.querySelectorAll("[data-secret-value]")) node.replaceChildren();
}

window.addEventListener("pagehide", clearPresentedValues);
window.addEventListener("pageshow", (event) => {
  if (event.persisted) clearPresentedValues();
});
document.addEventListener("submit", clearPresentedValues);
