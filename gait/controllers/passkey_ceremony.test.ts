import { afterEach, describe, expect, it, vi } from "vitest";

import {
  CEREMONY_REDIRECTED,
  ceremonyErrorMessage,
  postCeremonyJson,
} from "@/controllers/passkey_ceremony";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("postCeremonyJson", () => {
  it("falls back when the error response names no content type", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => ({
        ok: false,
        status: 422,
        headers: { get: () => null },
        json: async () => ({ error: "上限です" }),
      })),
    );

    await expect(postCeremonyJson("/x", {}, "failed")).rejects.toThrow("failed");
  });

  it("reloads on an expired session", async () => {
    const reload = vi.fn();
    vi.stubGlobal("location", { reload });
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("gone", { status: 401 })),
    );

    await expect(postCeremonyJson("/x", {}, "failed")).resolves.toBe(CEREMONY_REDIRECTED);
    expect(reload).toHaveBeenCalled();
  });

  it("opens the explicit step-up entry without replaying the rejected mutation", async () => {
    const location = {
      href: "https://base.example.test/identity/passkeys/passkey-1?ri=jp",
      origin: "https://base.example.test",
      assign: vi.fn(),
    };
    const fetchRequest = vi.fn(
      async () =>
        new Response("Confirm your identity", {
          status: 401,
          headers: {
            "WWW-Authenticate": 'Bearer error="insufficient_user_authentication"',
            "Content-Type": "text/plain",
          },
        }),
    );
    vi.stubGlobal("window", { location });
    vi.stubGlobal("fetch", fetchRequest);

    await expect(
      postCeremonyJson("/sensitive-operation", { confirm: true }, "failed"),
    ).resolves.toBe(CEREMONY_REDIRECTED);

    expect(fetchRequest).toHaveBeenCalledTimes(1);
    expect(location.assign).toHaveBeenCalledTimes(1);
  });
});

describe("ceremonyErrorMessage", () => {
  const messages = { NotAllowedError: "cancelled", fallback: "failed" };

  it("uses the named copy, then the error message, then the fallback", () => {
    const named = new Error("ignored");
    named.name = "NotAllowedError";
    expect(ceremonyErrorMessage(named, messages)).toBe("cancelled");

    expect(ceremonyErrorMessage(new Error("specific"), messages)).toBe("specific");

    const empty = new Error("");
    empty.name = "Other";
    expect(ceremonyErrorMessage(empty, messages)).toBe("failed");
    expect(ceremonyErrorMessage("nope", messages)).toBe("failed");
  });
});
