// The OTP resend button on the surfaces that do not boot React.
//
// The button is a rate limit made visible: the server decides when another code may be sent, and
// the controller reflects that decision as a countdown the visitor can read.
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import OtpResendController from "@/controllers/otp_resend_controller";

import { jsonResponse, requestBody } from "../support/http";
import { mountController } from "../support/stimulus";

const MARKUP = `
  <div data-controller="otp-resend"
       data-otp-resend-endpoint-value="/otp/resend"
       data-otp-resend-state-value="some-state"
       data-otp-resend-button-label-value="Resend OTP"
       data-otp-resend-sent-message-value="OTP Sent!"
       data-otp-resend-too-soon-message-value="Too soon"
       data-otp-resend-failed-message-value="Failed to send">
    <input type="text" data-otp-resend-target="input" value="123456">
    <button type="button" data-otp-resend-target="button">Resend OTP</button>
    <p data-otp-resend-target="status"></p>
  </div>
`;

const mount = (html = MARKUP) =>
  mountController<OtpResendController>("otp-resend", OtpResendController, html);

const statusText = (element: HTMLElement) =>
  element.querySelector("[data-otp-resend-target='status']")?.textContent ?? null;

const button = (element: HTMLElement) =>
  element.querySelector<HTMLButtonElement>("[data-otp-resend-target='button']");

const input = (element: HTMLElement) =>
  element.querySelector<HTMLInputElement>("[data-otp-resend-target='input']");

beforeEach(() => {
  vi.useFakeTimers();
  document.head.innerHTML = '<meta name="csrf-token" content="a-token">';
});

afterEach(() => {
  vi.useRealTimers();
});

describe("OtpResendController", () => {
  it("clears the code field and confirms when the server sent another code", async () => {
    const fetchMock = vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ resendable: true }));
    vi.stubGlobal("fetch", fetchMock);
    const { controller, element } = await mount();

    await controller.resend(new Event("click"));

    expect(requestBody(fetchMock)).toEqual({ state: "some-state" });
    expect(statusText(element)).toBe("OTP Sent!");
    expect(input(element)?.value).toBe("");
    expect(button(element)?.disabled).toBe(false);
  });

  it("counts down and re-enables the button when the server says it is too soon", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ retry_after: 2 }, 429)),
    );
    const { controller, element } = await mount();

    await controller.resend(new Event("click"));

    expect(statusText(element)).toBe("Too soon");
    expect(button(element)?.disabled).toBe(true);
    expect(button(element)?.textContent).toBe("Too soon (2s)");

    vi.advanceTimersByTime(1000);
    expect(button(element)?.textContent).toBe("Too soon (1s)");

    vi.advanceTimersByTime(1000);
    expect(button(element)?.disabled).toBe(false);
    expect(button(element)?.textContent).toBe("Resend OTP");
  });

  it("re-enables immediately when the server names no wait", async () => {
    vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, 429)));
    const { controller, element } = await mount();

    await controller.resend(new Event("click"));

    expect(statusText(element)).toBe("Too soon");
    expect(button(element)?.disabled).toBe(false);
  });

  it("ignores a second press while the countdown is running", async () => {
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValue(jsonResponse({ retry_after: 5 }, 429));
    vi.stubGlobal("fetch", fetchMock);
    const { controller } = await mount();

    await controller.resend(new Event("click"));
    await controller.resend(new Event("click"));

    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("reports a refusal it has no other copy for", async () => {
    vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({}, 500)));
    const { controller, element } = await mount();

    await controller.resend(new Event("click"));

    expect(statusText(element)).toBe("Failed to send");
  });

  it("reports a resend the server declined without saying so", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ resendable: false })),
    );
    const { controller, element } = await mount();

    await controller.resend(new Event("click"));

    expect(statusText(element)).toBe("Failed to send");
  });

  it("reports a request that never reached the server", async () => {
    vi.stubGlobal("fetch", vi.fn<typeof fetch>().mockRejectedValue(new Error("offline")));
    const { controller, element } = await mount();

    await controller.resend(new Event("click"));

    expect(statusText(element)).toBe("Failed to send");
  });

  it("does not fail when the markup carries no code field", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ resendable: true })),
    );
    const withoutInput = MARKUP.replace(
      '<input type="text" data-otp-resend-target="input" value="123456">',
      "",
    );
    const { controller, element } = await mount(withoutInput);

    await controller.resend(new Event("click"));

    expect(statusText(element)).toBe("OTP Sent!");
  });

  it("stops its countdown when it leaves the page", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn<typeof fetch>().mockResolvedValue(jsonResponse({ retry_after: 5 }, 429)),
    );
    const { controller, element } = await mount();
    await controller.resend(new Event("click"));

    controller.disconnect();
    vi.advanceTimersByTime(5000);

    // The label is frozen where the countdown stopped rather than continuing to tick.
    expect(button(element)?.textContent).toBe("Too soon (5s)");
  });
});
