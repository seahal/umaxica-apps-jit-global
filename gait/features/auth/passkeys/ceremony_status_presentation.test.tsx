import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, expect, it, vi } from "vitest";

import { PASSKEY_MESSAGES } from "@/features/auth/passkeys/messages";
import PasskeyAuthenticationPanel from "@/features/auth/passkeys/PasskeyAuthenticationPanel";

afterEach(() => vi.unstubAllGlobals());

it("keeps a polite status region mounted and reports an unsupported browser once as an error", async () => {
  vi.stubGlobal("PublicKeyCredential", undefined);
  render(
    <PasskeyAuthenticationPanel
      options_url="/options"
      verification_url="/verify"
      region="jp"
      identifier_param={null}
      field={null}
      turnstile_site_key="synthetic"
      turnstile_error_message="Try again"
      submit_label="Continue"
    />,
  );
  const status = screen.getByRole("status");
  expect(status.textContent).toBe("");
  await userEvent.setup().click(screen.getByRole("button", { name: "Continue" }));
  expect(screen.getByRole("alert").textContent).toBe(PASSKEY_MESSAGES.unsupported);
  expect(screen.getAllByRole("alert")).toHaveLength(1);
  expect(screen.getByRole("status")).toBe(status);
  expect(status.textContent).toBe("");
});
