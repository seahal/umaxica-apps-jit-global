// The rendered Turnstile challenge that feeds a form's hidden token field.
//
// The token is never trusted here -- the server validates it -- so what these specs pin down is
// that a challenge which cannot be presented leaves the field empty, which is what makes the
// server reject the submission instead of the client deciding it passed.
import { act } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import TurnstileWidget from "@/features/turnstile/TurnstileWidget";
import type { TurnstileApi, TurnstileOptions } from "@/lib/turnstile";

import { mount } from "../../support/react";

const SCRIPT_HTML = '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';

let rendered: { element: HTMLElement; options: TurnstileOptions }[];
let api: TurnstileApi;

const stubTurnstile = () => {
  rendered = [];
  api = {
    render: vi.fn((element: HTMLElement, options: TurnstileOptions) => {
      rendered.push({ element, options });
      return "widget-1";
    }),
    execute: vi.fn(),
    remove: vi.fn(),
  };
  window.turnstile = api;
};

const tokenField = (container: HTMLElement): HTMLInputElement | null =>
  container.querySelector<HTMLInputElement>('input[name="cf-turnstile-response"]');

const settle = async () => {
  await act(async () => {
    await Promise.resolve();
    await Promise.resolve();
  });
};

beforeEach(() => {
  stubTurnstile();
});

afterEach(() => {
  delete window.turnstile;
  document.head.innerHTML = "";
  vi.restoreAllMocks();
});

describe("TurnstileWidget", () => {
  it("writes the token Turnstile reports into the field the form submits", async () => {
    const onToken = vi.fn();
    const screen = mount(
      <TurnstileWidget
        site_key="site-key"
        onToken={onToken}
      />,
    );
    await settle();

    expect(tokenField(screen.container)?.value).toBe("");

    act(() => {
      rendered[0]?.options.callback("turnstile-token");
    });

    expect(tokenField(screen.container)?.value).toBe("turnstile-token");
    expect(onToken).toHaveBeenCalledWith("turnstile-token");
  });

  it("passes the action and customer data the server supplied", async () => {
    mount(
      <TurnstileWidget
        site_key="site-key"
        action="sign-in"
        cdata="tenant-1"
      />,
    );
    await settle();

    expect(rendered[0]?.options).toMatchObject({
      sitekey: "site-key",
      action: "sign-in",
      cData: "tenant-1",
    });
  });

  it("omits an action and customer data the server left empty", async () => {
    mount(
      <TurnstileWidget
        site_key="site-key"
        action=""
        cdata={null}
      />,
    );
    await settle();

    expect(rendered[0]?.options).not.toHaveProperty("action");
    expect(rendered[0]?.options).not.toHaveProperty("cData");
  });

  it("runs the challenge immediately in execute mode", async () => {
    mount(
      <TurnstileWidget
        site_key="site-key"
        mode="execute"
      />,
    );
    await settle();

    expect(api.execute).toHaveBeenCalledWith("widget-1");
  });

  it("waits for the visitor in render mode", async () => {
    mount(<TurnstileWidget site_key="site-key" />);
    await settle();

    expect(api.execute).not.toHaveBeenCalled();
  });

  it.each([
    ["error-callback"],
    ["expired-callback"],
    ["timeout-callback"],
    ["unsupported-callback"],
  ] as const)("clears the token when Turnstile reports %s", async (callback) => {
    const onToken = vi.fn();
    const screen = mount(
      <TurnstileWidget
        site_key="site-key"
        onToken={onToken}
      />,
    );
    await settle();

    act(() => {
      rendered[0]?.options.callback("turnstile-token");
    });
    act(() => {
      rendered[0]?.options[callback]?.("code");
    });

    expect(tokenField(screen.container)?.value).toBe("");
    expect(onToken).toHaveBeenLastCalledWith("");
  });

  it("clears the token without a listener to notify", async () => {
    const screen = mount(<TurnstileWidget site_key="site-key" />);
    await settle();

    act(() => {
      rendered[0]?.options.callback("turnstile-token");
    });
    act(() => {
      rendered[0]?.options["error-callback"]?.("code");
    });

    expect(tokenField(screen.container)?.value).toBe("");
  });

  it("reports a challenge that could not be presented, leaving the field empty", async () => {
    delete window.turnstile;
    const screen = mount(
      <TurnstileWidget
        site_key="site-key"
        error_message="検証を表示できませんでした"
      />,
    );
    await settle();

    expect(screen.text("[role=alert]")).toBe("検証を表示できませんでした");
    expect(tokenField(screen.container)?.value).toBe("");
  });

  it("falls back to its own message when the page supplied none", async () => {
    delete window.turnstile;
    const screen = mount(<TurnstileWidget site_key="site-key" />);
    await settle();

    expect(screen.text("[role=alert]")).toBe(
      "Security verification failed. Please refresh and try again.",
    );
  });

  it("stays silent when the widget was unmounted before the script failed", async () => {
    delete window.turnstile;
    document.head.innerHTML = SCRIPT_HTML;
    const script = document.querySelector("script");

    const screen = mount(<TurnstileWidget site_key="site-key" />);
    const alertBefore = screen.text("[role=alert]");
    screen.unmount();
    act(() => {
      script?.dispatchEvent(new Event("error"));
    });
    await settle();

    expect(alertBefore).toBeNull();
    expect(api.render).not.toHaveBeenCalled();
  });

  it("does not render into a widget that was unmounted while the script loaded", async () => {
    delete window.turnstile;
    document.head.innerHTML = SCRIPT_HTML;
    const script = document.querySelector("script");

    const screen = mount(<TurnstileWidget site_key="site-key" />);
    screen.unmount();
    window.turnstile = api;
    act(() => {
      script?.dispatchEvent(new Event("load"));
    });
    await settle();

    expect(api.render).not.toHaveBeenCalled();
  });

  it("removes the widget it rendered when the page moves on", async () => {
    const screen = mount(<TurnstileWidget site_key="site-key" />);
    await settle();
    screen.unmount();

    expect(api.remove).toHaveBeenCalledWith("widget-1");
  });
});
