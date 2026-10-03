import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

// The session-limit resolution travels on one of two channels the server chooses: a named
// challenge field, or nothing at all when this browser's own session holds the sign-in flow. The
// form transport is replaced so the spec can read exactly which fields the page hands it.
const patch = vi.fn();
const submitted: Record<string, unknown>[] = [];

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: vi.fn() },
  usePage: () => ({ props: {} }),
  useForm: (initial: Record<string, unknown>) => ({
    data: initial,
    setData: vi.fn(),
    errors: {},
    processing: false,
    patch: (action: string) => {
      submitted.push(initial);
      patch(action);
    },
  }),
}));

const { default: SignInLimitationShow } = await import("@/pages/base/app/sign/in/limitations/show");

const props = {
  title: "Session limit",
  heading: "Session limit",
  description: "Revoke one existing session to continue signing in.",
  session_label: "Session",
  error: null,
  notice: null,
  action: "/sign/in/limitation",
  cancel_action: "/sign/in/limitation",
  submit_label: "Revoke and continue",
  cancel_label: "Cancel sign-in",
  sessions: [],
};

afterEach(() => {
  submitted.length = 0;
  patch.mockClear();
});

describe("SignInLimitationShow resolution channel", () => {
  it("submits only the session choice when the browser session itself is the binding", () => {
    render(
      <SignInLimitationShow
        {...props}
        resolution={null}
      />,
    );

    fireEvent.submit(screen.getByRole("button", { name: "Revoke and continue" }));

    expect(patch).toHaveBeenCalledWith("/sign/in/limitation");
    expect(submitted).toEqual([{ session_ref: "" }]);
  });

  it("submits the challenge under the field name the server chose", () => {
    render(
      <SignInLimitationShow
        {...props}
        resolution={{ field: "resolution_challenge", value: "ch_1" }}
      />,
    );

    fireEvent.submit(screen.getByRole("button", { name: "Revoke and continue" }));

    expect(submitted).toEqual([{ session_ref: "", resolution_challenge: "ch_1" }]);
  });
});
