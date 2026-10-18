import { afterEach, describe, expect, it } from "vitest";

import { csrfToken } from "@/lib/csrf";

afterEach(() => {
  document.head.innerHTML = "";
});

describe("csrfToken", () => {
  it("reads the token the layout rendered into the meta tag", () => {
    document.head.innerHTML = '<meta name="csrf-token" content="a-token">';

    expect(csrfToken()).toBe("a-token");
  });

  it("answers an empty string when the layout rendered no tag", () => {
    expect(csrfToken()).toBe("");
  });
});
