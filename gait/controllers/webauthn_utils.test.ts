import { describe, expect, test } from "vitest";

import {
  normalizeCreationOptions,
  normalizePublicKeyOptions,
  normalizeRequestOptions,
  toArrayBuffer,
} from "@/controllers/webauthn_utils";

/** Reads a normalized field without claiming to know the whole shape it belongs to. */
const field = (options: Record<string, unknown>, name: string): unknown => options[name];

/** Reads a nested field, for the credential lists and the user entity. */
const nested = (value: unknown, name: string): unknown =>
  typeof value === "object" && value !== null ? Reflect.get(value, name) : undefined;

const firstOf = (value: unknown): unknown => (Array.isArray(value) ? value[0] : undefined);

// The test needs a constructor whose `name` can be blanked out, to prove toArrayBuffer
// falls back to `typeof`. Typing `prototype` explicitly keeps it off `any`, which the
// unsafe-argument rules would otherwise flag at the Object.create call below.
const AnonymousHolder: { prototype: object; name: string } = function AnonymousHolder() {
  // Never called - only its prototype and name matter.
};

describe("webauthn_utils", () => {
  describe("toArrayBuffer", () => {
    test("Base64URL 文字列を ArrayBuffer に変換する", () => {
      const input = "SGVsbG8td29ybGQ_"; // Hello-world? (Base64URL)
      const buffer = toArrayBuffer(input);
      expect(buffer).toBeInstanceOf(ArrayBuffer);
      const bytes = new Uint8Array(buffer);
      expect(bytes[0]).toBe(72); // 'H'
    });

    test("ArrayBuffer をそのまま返す", () => {
      const buffer = new ArrayBuffer(8);
      expect(toArrayBuffer(buffer)).toBe(buffer);
    });

    test("バイト配列を ArrayBuffer に変換する", () => {
      const input = [72, 101, 108, 108, 111];
      const buffer = toArrayBuffer(input);
      expect(new Uint8Array(buffer)[0]).toBe(72);
    });

    test("null のとき TypeError を投げる", () => {
      expect(() => toArrayBuffer(null)).toThrow(TypeError);
      expect(() => toArrayBuffer(null)).toThrow("null");
    });

    test("undefined のとき TypeError を投げる", () => {
      expect(() => toArrayBuffer(undefined)).toThrow(TypeError);
      expect(() => toArrayBuffer(undefined)).toThrow("undefined");
    });

    test("number のとき TypeError を投げる", () => {
      expect(() => toArrayBuffer(123)).toThrow(TypeError);
      expect(() => toArrayBuffer(123)).toThrow("number");
    });

    test("constructor のないオブジェクトで typeof fallback を確認する", () => {
      const obj: unknown = Object.create(null);
      expect(() => toArrayBuffer(obj)).toThrow("object");
    });

    test("名前のない constructor でも typeof fallback になる", () => {
      Object.defineProperty(AnonymousHolder, "name", { value: "" });
      const anonymous: unknown = Object.create(AnonymousHolder.prototype);
      expect(() => toArrayBuffer(anonymous)).toThrow("object");
    });
  });

  describe("normalizePublicKeyOptions", () => {
    test("challenge と user.id を Base64URL から ArrayBuffer に変換する", () => {
      const options = { challenge: "Y2hhbGxlbmdl", user: { id: "dXNlcmlk" } };
      const normalized = normalizePublicKeyOptions(options);
      expect(field(normalized, "challenge")).toBeInstanceOf(ArrayBuffer);
      expect(nested(field(normalized, "user"), "id")).toBeInstanceOf(ArrayBuffer);
    });

    test("publicKey プロパティがある場合、その中身を正規化する", () => {
      const options = { publicKey: { challenge: "Y2hhbGxlbmdl" } };
      const normalized = normalizePublicKeyOptions(options);
      expect(field(normalized, "challenge")).toBeInstanceOf(ArrayBuffer);
    });

    test("excludeCredentials がオブジェクトでない要素は空の記録として扱う", () => {
      expect(() => normalizePublicKeyOptions({ excludeCredentials: ["not-an-object"] })).toThrow(
        "excludeCredentials[0].id",
      );
    });

    test("excludeCredentials の id を正規化する", () => {
      const options = { excludeCredentials: [{ id: "Y3JlZGlk" }] };
      const normalized = normalizePublicKeyOptions(options);
      expect(nested(firstOf(field(normalized, "excludeCredentials")), "id")).toBeInstanceOf(
        ArrayBuffer,
      );
    });

    test("allowCredentials の id を正規化する", () => {
      const options = { allowCredentials: [{ id: "YWxsb3dpZA" }] };
      const normalized = normalizePublicKeyOptions(options);
      expect(nested(firstOf(field(normalized, "allowCredentials")), "id")).toBeInstanceOf(
        ArrayBuffer,
      );
    });

    test("null や undefined の options に TypeError を投げる", () => {
      expect(() => normalizePublicKeyOptions(null)).toThrow(TypeError);
      expect(() => normalizePublicKeyOptions(undefined)).toThrow(TypeError);
      expect(() => normalizePublicKeyOptions("string")).toThrow(TypeError);
    });

    test("excludeCredentials が undefined のときそのままにする", () => {
      const options = { challenge: "Y2hhbGxlbmdl" };
      const normalized = normalizePublicKeyOptions(options);
      expect(field(normalized, "excludeCredentials")).toBeUndefined();
    });

    test("excludeCredentials が null のときそのままにする", () => {
      const options = { excludeCredentials: null };
      const normalized = normalizePublicKeyOptions(options);
      expect(field(normalized, "excludeCredentials")).toBeNull();
    });

    test("excludeCredentials が配列でないとき TypeError を投げる", () => {
      const options = { excludeCredentials: "not-array" };
      expect(() => normalizePublicKeyOptions(options)).toThrow(TypeError);
    });

    test("allowCredentials が配列でないとき TypeError を投げる", () => {
      const options = { allowCredentials: "not-array" };
      expect(() => normalizePublicKeyOptions(options)).toThrow(TypeError);
    });
  });

  describe("normalizeRequestOptions", () => {
    test("答えは challenge を持つ、ブラウザが要求する形になっている", () => {
      const options = normalizeRequestOptions({ challenge: "Y2hhbGxlbmdl" });

      expect(options.challenge).toBeInstanceOf(ArrayBuffer);
    });

    test("challenge のない payload を、その項目を名指しして拒む", () => {
      expect(() => normalizeRequestOptions({})).toThrow("challenge");
    });
  });

  describe("normalizeCreationOptions", () => {
    const CREATION = {
      challenge: "Y2hhbGxlbmdl",
      rp: { name: "Umaxica", id: "example.test" },
      user: { id: "dXNlcmlk", name: "someone@example.test", displayName: "Someone" },
      pubKeyCredParams: [{ type: "public-key", alg: -7 }],
    };

    test("答えは WebAuthn が要求する項目をすべて持っている", () => {
      const options = normalizeCreationOptions(CREATION);

      expect(options.challenge).toBeInstanceOf(ArrayBuffer);
      expect(options.user.id).toBeInstanceOf(ArrayBuffer);
      expect(options.rp).toEqual({ name: "Umaxica", id: "example.test" });
      expect(options.pubKeyCredParams).toHaveLength(1);
    });

    test("rp.id が無い payload は name だけ残す", () => {
      const options = normalizeCreationOptions({ ...CREATION, rp: { name: "Umaxica" } });

      expect(options.rp).toEqual({ name: "Umaxica" });
    });

    test("pubKeyCredParams alg が数値でない payload を拒む", () => {
      expect(() =>
        normalizeCreationOptions({
          ...CREATION,
          pubKeyCredParams: [{ type: "public-key", alg: "-7" }],
        }),
      ).toThrow("alg");
    });

    test("rp を持たない payload を拒む", () => {
      expect(() => normalizeCreationOptions({ ...CREATION, rp: undefined })).toThrow("rp");
    });

    test("user を持たない payload を拒む", () => {
      expect(() => normalizeCreationOptions({ ...CREATION, user: undefined })).toThrow("user");
    });

    test("pubKeyCredParams を持たない payload を拒む", () => {
      expect(() => normalizeCreationOptions({ ...CREATION, pubKeyCredParams: undefined })).toThrow(
        "pubKeyCredParams",
      );
    });

    test("user.name が文字列でない payload を、その項目を名指しして拒む", () => {
      const user = { ...CREATION.user, name: 42 };

      expect(() => normalizeCreationOptions({ ...CREATION, user })).toThrow("user.name");
    });
  });
});
