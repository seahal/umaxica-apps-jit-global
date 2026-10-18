import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

// Starting a TOTP enrolment is a document POST that issues a fresh secret. Like every document
// form on these pages it reads the authenticity token from the document when it is submitted.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: vi.fn(), patch: vi.fn(), post: vi.fn() },
  useForm: (initial: Record<string, string>) => ({
    data: initial,
    setData: vi.fn(),
    transform: vi.fn(),
    patch: vi.fn(),
    post: vi.fn(),
    processing: false,
    errors: {},
  }),
  usePage: () => ({ props: {} }),
}));

const { default: TotpsNew } = await import("@/pages/auth/app/settings/totps/new");

afterEach(() => {
  document.head.querySelectorAll('meta[name="csrf-token"]').forEach((meta) => meta.remove());
});

describe("TOTP enrolment start", () => {
  it("posts the start form with the token the document carries at submit time", () => {
    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "token-at-render";
    document.head.append(meta);

    const { container } = render(
      <TotpsNew
        title="Add an authenticator app"
        description="Register an authenticator app"
        back_link={{ label: "Back", href: "/settings/totps?ri=jp" }}
        start={{ action: "/settings/totps/enrollment?ri=jp", label: "Start enrolment" }}
        qr_code_image={null}
        qr_fallback="Cannot scan the QR code"
        form={{
          action: "/settings/totps?ri=jp",
          scope: "user_totp_credential",
          title_label: "Name",
          title_placeholder: "iPhone",
          title_hint: "A name you will recognise",
          title: null,
          enrollment_id: null,
          first_token_label: "Code",
          first_token_placeholder: "123456",
          first_token_help: "The code your app shows",
          first_token_delivery_help: "The code is shown in the app",
          submit_label: "Register",
        }}
        cancel={null}
        turnstile={{ site_key: "site-key", mode: "execute", action: null, cdata: null }}
        error_header={null}
        error_messages={[]}
      />,
    );
    const form = container.querySelector("form");
    const token = container.querySelector<HTMLInputElement>('input[name="authenticity_token"]');

    expect(form?.getAttribute("method")).toBe("post");
    expect(form?.getAttribute("action")).toBe("/settings/totps/enrollment?ri=jp");
    expect(token?.value).toBe("");

    meta.content = "token-at-submit";
    fireEvent.submit(screen.getByRole("button", { name: "Start enrolment" }));

    expect(token?.value).toBe("token-at-submit");
  });
});
