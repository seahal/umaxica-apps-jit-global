import { expect, it } from "vitest";

it("clears presented secrets on page exit, cached restoration and form submission", async () => {
  await import("@/entrypoints/secret_presentation");
  const secret = document.createElement("div");
  secret.dataset["secretValue"] = "";
  const ordinary = document.createElement("p");
  ordinary.textContent = "Public information";
  document.body.append(secret, ordinary);
  try {
    secret.textContent = "synthetic secret";
    window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: false }));
    expect(secret.textContent).toBe("synthetic secret");
    window.dispatchEvent(new PageTransitionEvent("pagehide"));
    expect(secret.childNodes.length).toBe(0);
    secret.textContent = "synthetic secret";
    window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: true }));
    expect(secret.childNodes.length).toBe(0);
    secret.textContent = "synthetic secret";
    document.dispatchEvent(new Event("submit"));
    expect(secret.childNodes.length).toBe(0);
    expect(ordinary.textContent).toBe("Public information");
  } finally {
    secret.remove();
    ordinary.remove();
  }
});
