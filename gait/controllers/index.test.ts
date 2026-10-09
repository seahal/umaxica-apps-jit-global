import { beforeEach, describe, expect, test, vi } from "vitest";

const register = vi.fn();

vi.mock("@hotwired/stimulus", () => ({
  Application: {
    start: vi.fn(() => ({
      register,
      debug: false,
    })),
  },
  Controller: class {
    connect() {}
  },
}));

describe("Controller index auto-registration", () => {
  beforeEach(() => {
    vi.resetModules();
    register.mockClear();
  });

  test("registers discovered controllers with kebab-cased names", async () => {
    await import("../../src/controllers/index.js");

    expect(register).toHaveBeenCalledWith("theme", expect.anything());
    expect(register).toHaveBeenCalledWith("theme-toggle", expect.anything());
    expect(register).toHaveBeenCalledWith("cookie-consent", expect.anything());
  });
});
