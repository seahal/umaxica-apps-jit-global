import { act } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import OtpResendButton from "@/features/auth/otp/OtpResendButton";

import { mount } from "../../../support/react";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe("OtpResendButton", () => {
  const messages = {
    button_label: "再送する",
    sent_message: "送信しました",
    too_soon_message: "しばらく待ってください",
    failed_message: "失敗しました",
  };

  it("counts down a 429 and ignores a press while waiting", async () => {
    vi.useFakeTimers();
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ retry_after: 2 }), { status: 429 })),
    );
    const screen = mount(
      <OtpResendButton
        endpoint="/otp"
        state="state"
        messages={messages}
      />,
    );

    screen.click("button");
    await screen.flush();

    expect(screen.container.querySelector("button")?.disabled).toBe(true);

    await screen.flush();
    screen.click("button");
    expect(vi.mocked(fetch).mock.calls).toHaveLength(1);

    act(() => {
      vi.advanceTimersByTime(1000);
    });
    expect(screen.container.querySelector("button")?.textContent).toContain("(1");
  });

  it("starts no wait when the 429 names none", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({}), { status: 429 })),
    );
    const screen = mount(
      <OtpResendButton
        endpoint="/otp"
        state="state"
        messages={messages}
      />,
    );

    screen.click("button");
    await screen.flush();

    expect(screen.text("p")).toBe("しばらく待ってください");
    expect(screen.container.querySelector("button")?.disabled).toBe(false);
  });

  it("reports a successful resend", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response(JSON.stringify({ resendable: true }), { status: 200 })),
    );
    const onResent = vi.fn();
    const screen = mount(
      <OtpResendButton
        endpoint="/otp"
        state="state"
        messages={messages}
        onResent={onResent}
      />,
    );

    screen.click("button");
    await screen.flush();

    expect(onResent).toHaveBeenCalled();
    expect(screen.text("p")).toBe("送信しました");
  });
});
