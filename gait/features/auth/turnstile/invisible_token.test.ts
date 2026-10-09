// The on-demand Turnstile token the sign-in passkey panel solves before it calls the server.
//
// Every failure path here must reject: a challenge that could not be presented is never a passed
// challenge, and the caller surfaces the rejection rather than continuing without a token.
import { afterEach, describe, expect, it, vi } from "vitest";

import { solveInvisibleTurnstile } from "@/features/auth/turnstile/invisibleToken";
import type { TurnstileApi, TurnstileOptions } from "@/lib/turnstile";

const ERROR_MESSAGE = "検証に失敗しました";

/** Captures the options the widget was rendered with so a spec can drive its callbacks. */
function stubTurnstile(render?: TurnstileApi["render"]) {
  const rendered: { container: HTMLElement; options: TurnstileOptions }[] = [];
  const api: TurnstileApi = {
    render:
      render ??
      ((container: HTMLElement, options: TurnstileOptions) => {
        rendered.push({ container, options });
        return "widget-1";
      }),
    execute: vi.fn(),
    remove: vi.fn(),
  };
  window.turnstile = api;

  return rendered;
}

afterEach(() => {
  delete window.turnstile;
  document.body.innerHTML = "";
  vi.restoreAllMocks();
});

describe("solveInvisibleTurnstile", () => {
  it("refuses to run without a site key rather than answering an empty token", async () => {
    await expect(solveInvisibleTurnstile("", ERROR_MESSAGE, null)).rejects.toThrow(ERROR_MESSAGE);
  });

  it("rejects when the Turnstile script never arrived", async () => {
    await expect(solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null)).rejects.toThrow(
      ERROR_MESSAGE,
    );
  });

  it("resolves with the token the invisible widget reports", async () => {
    const rendered = stubTurnstile();
    const promise = solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null);
    await Promise.resolve();

    const [widget] = rendered;

    expect(widget?.options.sitekey).toBe("site-key");
    expect(widget?.options.size).toBe("invisible");
    // The host is hidden, so the widget is neither rendered nor announced.
    expect(widget?.container.hidden).toBe(true);
    expect(widget?.container.parentElement).toBe(document.body);

    widget?.options.callback("turnstile-token");

    await expect(promise).resolves.toBe("turnstile-token");
  });

  it("mounts the widget inside the host the caller supplied", async () => {
    const host = document.createElement("div");
    document.body.append(host);
    const rendered = stubTurnstile();

    const promise = solveInvisibleTurnstile("site-key", ERROR_MESSAGE, host);
    await Promise.resolve();
    rendered[0]?.options.callback("token");

    await expect(promise).resolves.toBe("token");
    expect(rendered[0]?.container.parentElement).toBe(host);
  });

  it.each([["error-callback"], ["expired-callback"]] as const)(
    "rejects when Turnstile reports %s",
    async (callback) => {
      const rendered = stubTurnstile();
      const promise = solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null);
      await Promise.resolve();

      rendered[0]?.options[callback]?.("code");

      await expect(promise).rejects.toThrow(ERROR_MESSAGE);
    },
  );

  it("rejects with the visitor-facing message when rendering itself throws", async () => {
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});
    stubTurnstile(() => {
      throw new Error("render exploded");
    });

    await expect(solveInvisibleTurnstile("site-key", ERROR_MESSAGE, null)).rejects.toThrow(
      ERROR_MESSAGE,
    );
    expect(consoleError).toHaveBeenCalled();
  });
});
