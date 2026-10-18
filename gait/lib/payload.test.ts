import { describe, expect, it } from "vitest";

import { readBoolean, readNumber, readObject, readRecord, readString } from "@/lib/payload";

describe("payload readers", () => {
  it("read string, number and boolean properties only when they have that type", () => {
    const payload = { name: "ok", count: 2, flag: true, other: {} };

    expect(readString(payload, "name")).toBe("ok");
    expect(readString(payload, "count")).toBeUndefined();
    expect(readNumber(payload, "count")).toBe(2);
    expect(readNumber(payload, "name")).toBeUndefined();
    expect(readBoolean(payload, "flag")).toBe(true);
    expect(readBoolean(payload, "name")).toBeUndefined();
  });

  it("answers undefined for a non-object payload", () => {
    expect(readString(null, "name")).toBeUndefined();
    expect(readNumber("x", "count")).toBeUndefined();
    expect(readBoolean(undefined, "flag")).toBeUndefined();
    expect(readObject(1, "nested")).toBeUndefined();
  });

  it("readObject keeps nested objects and drops null", () => {
    const nested = { inner: 1 };

    expect(readObject({ nested }, "nested")).toEqual(nested);
    expect(readObject({ nested: null }, "nested")).toBeUndefined();
    expect(readObject({ nested: "no" }, "nested")).toBeUndefined();
  });

  it("readRecord keeps only string-valued keys", () => {
    expect(readRecord({ a: "1", b: 2, c: null })).toEqual({ a: "1" });
    expect(readRecord(null)).toEqual({});
    expect(readRecord("no")).toEqual({});
  });
});
