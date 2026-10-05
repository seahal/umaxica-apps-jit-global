import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import SecretSignIn from "@/pages/auth/app/sign/in/secrets/new";

// The third-party challenge is outside this form relationship test.
vi.mock("@/features/turnstile/TurnstileWidget", () => ({ default: () => null }));

const turnstile = { site_key: "test", action: "sign_in", mode: "render" as const, cdata: null };

describe("Secret sign-in presentation", () => {
  it("describes the generic form rejection without treating it as a credential-specific validation failure", () => {
    render(
      <SecretSignIn
        title="Sign in"
        label="Secret"
        submit="Continue"
        error="Try again."
        action="/sign/in/secret"
        authenticity_token="synthetic"
        turnstile={turnstile}
      />,
    );
    expect(screen.getByRole("form", { name: "Sign in", description: "Try again." })).toBeTruthy();
    const control = screen.getByLabelText("Secret");
    expect(control.getAttribute("aria-invalid")).toBeNull();
    expect(control.getAttribute("name")).toBe("secret");
    expect(control.getAttribute("type")).toBe("password");
    expect(control.getAttribute("minlength")).toBe("32");
    expect(control.getAttribute("maxlength")).toBe("32");
    expect(control.getAttribute("autocomplete")).toBe("current-password");
  });

  it("retains the document POST and empty initial state without an error relationship", () => {
    render(
      <SecretSignIn
        title="Sign in"
        label="Secret"
        submit="Continue"
        error={null}
        action="/sign/in/secret"
        authenticity_token="synthetic"
        turnstile={turnstile}
      />,
    );
    const form = screen.getByRole("form", { name: "Sign in" });
    expect(form.getAttribute("method")).toBe("post");
    expect(form.getAttribute("action")).toBe("/sign/in/secret");
    expect(form.getAttribute("aria-describedby")).toBeNull();
    expect(screen.getByLabelText<HTMLInputElement>("Secret").value).toBe("");
    expect(screen.getByRole("button", { name: "Continue" }).getAttribute("type")).toBe("submit");
  });
});
