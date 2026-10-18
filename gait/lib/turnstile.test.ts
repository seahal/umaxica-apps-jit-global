import { afterEach, describe, expect, it, vi } from "vitest";

import { type TurnstileApi, waitForTurnstileApi } from "@/lib/turnstile";

const turnstileApi = (): TurnstileApi => ({
  render: vi.fn(() => "widget-1"),
  execute: vi.fn(),
  remove: vi.fn(),
});

/** The script tag the layout renders; the specs below drive its load and error events. */
function scriptTag(): HTMLScriptElement {
  document.head.innerHTML = SCRIPT_HTML;
  const script = document.querySelector("script");

  if (!script) {
    throw new Error("The Turnstile script tag was not rendered into the document.");
  }

  return script;
}

const SCRIPT_HTML = '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';

describe("waitForTurnstileApi", () => {
  afterEach(() => {
    document.head.innerHTML = "";
    delete window.turnstile;
    vi.useRealTimers();
  });

  it("resolves immediately when window.turnstile is already present", async () => {
    window.turnstile = turnstileApi();

    await expect(waitForTurnstileApi("missing")).resolves.toBe(window.turnstile);
  });

  it("rejects immediately when the Turnstile script tag is not on the page", async () => {
    await expect(waitForTurnstileApi("no script tag")).rejects.toThrow("no script tag");
  });

  it("resolves once the script loads and window.turnstile becomes available", async () => {
    const script = scriptTag();
    const promise = waitForTurnstileApi("timed out");

    window.turnstile = turnstileApi();
    script.dispatchEvent(new Event("load"));

    await expect(promise).resolves.toBe(window.turnstile);
  });

  it("rejects when the script loads but window.turnstile never appears", async () => {
    const script = scriptTag();
    const promise = waitForTurnstileApi("turnstile missing after load");

    script.dispatchEvent(new Event("load"));

    await expect(promise).rejects.toThrow("turnstile missing after load");
  });

  it("rejects when the script tag fires an error event", async () => {
    const script = scriptTag();
    const promise = waitForTurnstileApi("script failed to load");

    script.dispatchEvent(new Event("error"));

    await expect(promise).rejects.toThrow("script failed to load");
  });

  it("rejects once the timeout elapses without the script settling", async () => {
    vi.useFakeTimers();
    scriptTag();

    const promise = waitForTurnstileApi("timed out", 1000);
    const settled = promise.catch((error: unknown) => error);

    await vi.advanceTimersByTimeAsync(1000);

    await expect(settled).resolves.toMatchObject({ message: "timed out" });
  });
});
