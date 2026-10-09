import { fireEvent, render, screen } from "@testing-library/react";
import { useState } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

// The session-limit resolution travels on one of two channels the server chooses: a named
// challenge field, or nothing at all when this browser's own session holds the sign-in flow. The
// form transport is replaced by a stand-in that keeps the form's data as state and records what
// `patch` would send, so the spec reads the fields present at submit time.
type Submission = { url: string; data: Record<string, unknown> };
const submissions: Submission[] = [];

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: vi.fn() },
  usePage: () => ({ props: {} }),
  useForm: (initial: Record<string, unknown>) => {
    const [data, setDataState] = useState(initial);

    return {
      data,
      setData: (key: string, value: unknown) =>
        setDataState((current) => ({ ...current, [key]: value })),
      errors: {},
      processing: false,
      patch: (url: string) => {
        submissions.push({ url, data });
      },
    };
  },
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
  sessions: [
    {
      session_ref: "ref_1",
      restriction_label: "Normal",
      created_label: "Created 01/02",
      last_used_label: null,
      revoke_label: "Revoke this session",
    },
  ],
};

afterEach(() => {
  submissions.length = 0;
});

describe("SignInLimitationShow resolution channel", () => {
  it("submits only the chosen session when the browser session itself is the binding", () => {
    render(
      <SignInLimitationShow
        {...props}
        resolution={null}
      />,
    );

    fireEvent.click(screen.getByRole("radio"));
    fireEvent.submit(screen.getByRole("button", { name: "Revoke and continue" }));

    expect(submissions).toEqual([{ url: "/sign/in/limitation", data: { session_ref: "ref_1" } }]);
  });

  it("submits the chosen session with the challenge under the field name the server chose", () => {
    render(
      <SignInLimitationShow
        {...props}
        resolution={{ field: "resolution_challenge", value: "ch_1" }}
      />,
    );

    fireEvent.click(screen.getByRole("radio"));
    fireEvent.submit(screen.getByRole("button", { name: "Revoke and continue" }));

    expect(submissions).toEqual([
      { url: "/sign/in/limitation", data: { session_ref: "ref_1", resolution_challenge: "ch_1" } },
    ]);
  });
});
