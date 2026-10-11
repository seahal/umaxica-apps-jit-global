import { afterEach, describe, expect, it } from "vitest";

import { csrfToken } from "@/features/auth/signup/csrf";

afterEach(() => {
  document.head.innerHTML = "";
});

describe("sign-up csrfToken", () => {
  it("reads the token the layout rendered into the meta tag", () => {
    document.head.innerHTML = '<meta name="csrf-token" content="a-token">';

    expect(csrfToken()).toBe("a-token");
  });

  it("answers an empty string when the layout rendered no tag", () => {
    expect(csrfToken()).toBe("");
  });

  it("answers an empty string when the tag has no content", () => {
    document.head.innerHTML = '<meta name="csrf-token">';

    expect(csrfToken()).toBe("");
  });
});
