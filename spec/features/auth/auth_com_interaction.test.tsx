import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { answerConfirmation } from "../../support/confirmation";

// These specs mount the ceremonies and fire real DOM events, which is the only way to reach the
// request branches: what the delete control sends, and how the resend control reacts to each answer
// the server can give.
const deleteRequest = vi.fn();
const postRequest = vi.fn();
const patchRequest = vi.fn();
const setData = vi.fn();

// The mocked form carries no server errors; naming the type here rather than asserting an empty
// object into it keeps the mock's shape the same as the adapter's.
const NO_ERRORS: Record<string, string> = {};

vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: React.ReactNode }) => (
    <a href={href}>{children}</a>
  ),
  router: { delete: deleteRequest, post: postRequest, patch: patchRequest },
  usePage: () => ({ props: { errors: {} } }),
  useForm: (initial: Record<string, unknown>) => ({
    data: initial,
    setData,
    errors: NO_ERRORS,
    processing: false,
    post: postRequest,
    patch: patchRequest,
  }),
}));

vi.mock("@/features/turnstile/TurnstileWidget", () => ({
  default: ({ onToken }: { onToken?: (token: string) => void }) => {
    onToken?.("turnstile-token");
    return <div />;
  },
}));

const { default: PasskeyDeleteButton } =
  await import("@/features/auth/settings/PasskeyDeleteButton");
const { default: OtpResendButton } = await import("@/features/auth/otp/OtpResendButton");
const { default: SignInEmailNew } = await import("@/features/auth/SignInEmailNew");
const { default: PasskeyEdit } = await import("@/features/auth/settings/PasskeyEdit");

let container: HTMLDivElement;
let root: Root;

const mount = (element: React.ReactElement) => {
  container = document.createElement("div");
  document.body.append(container);
  root = createRoot(container);
  act(() => {
    root.render(element);
  });
};

// React tracks the DOM value of a controlled input, so assigning `.value` directly is ignored.
// Writing through the native setter first is what makes the change event reach `onChange`.
const type = (input: HTMLInputElement, value: string) => {
  const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
  descriptor?.set?.call(input, value);
  act(() => {
    input.dispatchEvent(new Event("change", { bubbles: true }));
  });
};

// The confirmation is a rendered dialog, so it is answered by clicking one of its two buttons.

const click = (element: Element) => {
  act(() => {
    element.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  });
};

beforeEach(() => {
  vi.useRealTimers();
});

afterEach(() => {
  act(() => {
    root.unmount();
  });
  container.remove();
  vi.restoreAllMocks();
  deleteRequest.mockClear();
  postRequest.mockClear();
  patchRequest.mockClear();
  setData.mockClear();
});

const turnstile = {
  site_key: "site-key",
  mode: "execute" as const,
  action: null,
  cdata: null,
};

describe("PasskeyDeleteButton", () => {
  it("sends the DELETE with the challenge token once the actor confirms", () => {
    mount(
      <PasskeyDeleteButton
        action="/settings/passkey/pk_1"
        label="削除"
        confirm_message="削除しますか"
        turnstile={turnstile}
      />,
    );

    click(container.querySelector("button")!);
    answerConfirmation(true);

    expect(deleteRequest).toHaveBeenCalledWith("/settings/passkey/pk_1", {
      data: { "cf-turnstile-response": "turnstile-token" },
    });
  });

  it("sends nothing when the actor declines the confirmation", () => {
    mount(
      <PasskeyDeleteButton
        action="/settings/passkey/pk_1"
        label="削除"
        confirm_message="削除しますか"
        turnstile={turnstile}
      />,
    );

    click(container.querySelector("button")!);
    answerConfirmation(false);

    expect(deleteRequest).not.toHaveBeenCalled();
  });
});

const answer = (status: number, payload: unknown) => {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue({
      status,
      json: async () => payload,
    }),
  );
};

describe("OtpResendButton", () => {
  const messages = {
    button_label: "再送信",
    sent_message: "送信しました",
    too_soon_message: "しばらく待ってください",
    failed_message: "失敗しました",
  };

  const resend = async () => {
    const button = container.querySelector("button")!;
    await act(async () => {
      button.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    });
  };

  it("reports a delivered code and clears the field", async () => {
    const onResent = vi.fn();
    answer(200, { resendable: true });
    mount(
      <OtpResendButton
        endpoint="/web/v0/in/email/otp"
        state="resend-state"
        messages={messages}
        onResent={onResent}
      />,
    );

    await resend();

    expect(onResent).toHaveBeenCalled();
    expect(container.textContent).toContain("送信しました");
  });

  it("starts the cooldown the server dictated on 429", async () => {
    answer(429, { retry_after: 30 });
    mount(
      <OtpResendButton
        endpoint="/web/v0/in/email/otp"
        state="resend-state"
        messages={messages}
      />,
    );

    await resend();

    expect(container.textContent).toContain("しばらく待ってください (30s)");
    expect(container.querySelector("button")!.disabled).toBe(true);

    // A second press while the cooldown runs must not reach the endpoint again.
    await resend();

    expect(fetch).toHaveBeenCalledTimes(1);
  });

  it("reports a failure for any other answer", async () => {
    answer(500, {});
    mount(
      <OtpResendButton
        endpoint="/web/v0/in/email/otp"
        state="resend-state"
        messages={messages}
      />,
    );

    await resend();

    expect(container.textContent).toContain("失敗しました");
  });

  it("reports a failure when the request itself fails", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("offline")));
    mount(
      <OtpResendButton
        endpoint="/web/v0/in/email/otp"
        state="resend-state"
        messages={messages}
      />,
    );

    await resend();

    expect(container.textContent).toContain("失敗しました");
  });
});

describe("credential forms", () => {
  const submit = () => {
    act(() => {
      container
        .querySelector("form")!
        .dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
    });
  };

  it("SignInEmailNew posts to the action the server resolved", () => {
    mount(
      <SignInEmailNew
        title="メールでログイン"
        description="説明"
        action="/sign/in/email"
        pt={null}
        field_label="メールアドレス"
        submit_label="送信"
        back_link={{ label: "もどる", href: "/sign/in" }}
        turnstile={{ ...turnstile, mode: "render" }}
      />,
    );

    type(container.querySelector<HTMLInputElement>("input[type='email']")!, "name@example.com");
    submit();

    expect(setData).toHaveBeenCalledWith("user_email", { address: "name@example.com" });
    expect(postRequest).toHaveBeenCalledWith("/sign/in/email");
  });

  it("PasskeyEdit patches the rename to the same route the form named", () => {
    mount(
      <PasskeyEdit
        title="パスキーの編集"
        action="/settings/passkey/pk_1"
        field_label="説明"
        description="MacBook"
        submit_label="保存"
        cancel_link={{ label: "中止", href: "/settings/passkey" }}
        turnstile={turnstile}
      />,
    );

    type(container.querySelector<HTMLInputElement>("input[type='text']")!, "iPhone");
    submit();

    expect(setData).toHaveBeenCalledWith("visitor_passkey", { description: "iPhone" });
    expect(patchRequest).toHaveBeenCalledWith("/settings/passkey/pk_1");
  });
});
