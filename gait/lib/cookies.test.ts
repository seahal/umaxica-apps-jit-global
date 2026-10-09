// Reading the JS-readable cookies Rails publishes, through the Cookie Store API.
//
// The application never writes these cookies, so what is covered here is the read: the value the
// document carries, the shapes that mean "absent", and the failure the API's own absence is.
import { beforeEach, describe, expect, test, vi } from "vitest";

import { hasRecordedCookieConsent, readCookie, watchCookie } from "@/lib/cookies";

beforeEach(() => {
  for (const part of document.cookie.split(";")) {
    const [key] = part.trim().split("=");
    if (key) {
      document.cookie = `${key}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
    }
  }
});

describe("readCookie", () => {
  test("reads the value the document carries", async () => {
    document.cookie = "ct=dr; path=/";

    await expect(readCookie("ct")).resolves.toBe("dr");
  });

  test("reads the named cookie when the document carries several", async () => {
    document.cookie = "lx=en; path=/";
    document.cookie = "ct=li; path=/";
    document.cookie = "tz=asia%2Ftokyo; path=/";

    await expect(readCookie("ct")).resolves.toBe("li");
  });

  // The store hands back the value as stored, and Rails percent-encodes what it writes.
  test("decodes a percent encoded value", async () => {
    document.cookie = "tz=asia%2Ftokyo; path=/";

    await expect(readCookie("tz")).resolves.toBe("asia/tokyo");
  });

  test("answers null for a cookie the document does not carry", async () => {
    document.cookie = "lx=en; path=/";

    await expect(readCookie("ct")).resolves.toBeNull();
  });

  test("answers null for a cookie that carries no value", async () => {
    document.cookie = "ct=; path=/";

    await expect(readCookie("ct")).resolves.toBeNull();
  });

  // "Cannot tell" is not "absent": a document outside a secure context, or a browser without the
  // API, must say so rather than report every cookie as missing.
  test("fails loudly when the Cookie Store API is unavailable", async () => {
    vi.stubGlobal("cookieStore", undefined);

    await expect(readCookie("ct")).rejects.toThrow("window.cookieStore is unavailable");
  });
});

describe("watchCookie", () => {
  test("reports the new value when the cookie changes", async () => {
    const seen: (string | null)[] = [];
    const stopWatching = watchCookie("ct", (value) => seen.push(value));

    await cookieStore.set({ name: "ct", value: "dr" });
    stopWatching();

    expect(seen).toEqual(["dr"]);
  });

  test("decodes a percent encoded value the same way a read does", async () => {
    const seen: (string | null)[] = [];
    const stopWatching = watchCookie("tz", (value) => seen.push(value));

    await cookieStore.set({ name: "tz", value: "asia%2Ftokyo" });
    stopWatching();

    expect(seen).toEqual(["asia/tokyo"]);
  });

  test("reports null when the cookie is deleted", async () => {
    document.cookie = "ct=dr; path=/";
    const seen: (string | null)[] = [];
    const stopWatching = watchCookie("ct", (value) => seen.push(value));

    await cookieStore.delete("ct");
    stopWatching();

    expect(seen).toEqual([null]);
  });

  test("ignores changes to other cookies", async () => {
    const seen: (string | null)[] = [];
    const stopWatching = watchCookie("ct", (value) => seen.push(value));

    await cookieStore.set({ name: "lx", value: "en" });
    await cookieStore.delete("lx");
    stopWatching();

    expect(seen).toEqual([]);
  });

  test("stops reporting once unsubscribed", async () => {
    const seen: (string | null)[] = [];
    const stopWatching = watchCookie("ct", (value) => seen.push(value));

    stopWatching();
    await cookieStore.set({ name: "ct", value: "dr" });

    expect(seen).toEqual([]);
  });

  test("fails loudly when the Cookie Store API is unavailable", () => {
    vi.stubGlobal("cookieStore", undefined);

    expect(() => watchCookie("ct", () => {})).toThrow("window.cookieStore is unavailable");
  });
});

describe("hasRecordedCookieConsent", () => {
  test("reports an answered banner for the buffer cookie the server writes as 1", async () => {
    document.cookie = "preference_consented=1; path=/";

    await expect(hasRecordedCookieConsent()).resolves.toBe(true);
  });

  test("reports an unanswered banner for the buffer cookie the server writes as 0", async () => {
    document.cookie = "preference_consented=0; path=/";

    await expect(hasRecordedCookieConsent()).resolves.toBe(false);
  });

  // SameSite=Strict keeps the buffer off the first cross-site inbound hit, which reads as
  // unanswered and raises the banner - the safe direction to be wrong in.
  test("reports an unanswered banner when the buffer cookie is absent", async () => {
    await expect(hasRecordedCookieConsent()).resolves.toBe(false);
  });
});
