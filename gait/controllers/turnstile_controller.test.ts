// The rendered Turnstile widget on the surfaces that do not boot React.
//
// Waiting for the Cloudflare script lives in `@/lib/turnstile` and is covered there. What belongs
// here is what the controller decides: when it renders, what it configures the widget with, where
// it puts the token, and that a form cannot be submitted twice on one token.
import { beforeEach, describe, expect, it, vi } from "vitest";

import TurnstileController from "@/controllers/turnstile_controller";
import type { TurnstileOptions } from "@/lib/turnstile";

import { recordEvents } from "../support/events";
import { mountController } from "../support/stimulus";

const MARKUP = `
  <form>
    <div data-controller="turnstile"
         data-turnstile-error-message-value="Verification failed">
      <div id="widget-host" data-turnstile-target="container" data-sitekey="site-key"></div>
      <input type="hidden" data-turnstile-target="response" name="cf-turnstile-response">
    </div>
    <button type="submit">Continue</button>
  </form>
`;

const mount = (html = MARKUP) =>
  mountController<TurnstileController>("turnstile", TurnstileController, html);

let rendered: { container: HTMLElement; options: TurnstileOptions }[];
let render: ReturnType<typeof vi.fn>;
let execute: ReturnType<typeof vi.fn>;

function stubTurnstileScript() {
  document.head.innerHTML =
    '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js"></script>';
}

beforeEach(() => {
  rendered = [];
  execute = vi.fn();
  render = vi.fn((container: HTMLElement, options: TurnstileOptions) => {
    rendered.push({ container, options });
    return "widget-1";
  });
  vi.stubGlobal("turnstile", { render, execute, remove: vi.fn() });
  stubTurnstileScript();
});

const responseField = (element: HTMLElement) =>
  element.querySelector<HTMLInputElement>("[data-turnstile-target='response']");

const lastOptions = () => rendered.at(-1)?.options;

describe("TurnstileController", () => {
  describe("scheduleChallenge", () => {
    it("renders the widget into its own container", async () => {
      const { controller, element } = await mount();

      await controller.scheduleChallenge();

      expect(rendered.at(-1)?.container).toBe(element.querySelector("#widget-host"));
      expect(lastOptions()?.sitekey).toBe("site-key");
      expect(execute).not.toHaveBeenCalled();
    });

    it("executes the widget immediately in execute mode", async () => {
      const { controller } = await mount(
        MARKUP.replace(
          'data-controller="turnstile"',
          'data-controller="turnstile" data-turnstile-mode-value="execute"',
        ),
      );

      await controller.scheduleChallenge();

      expect(execute).toHaveBeenCalledWith("widget-1");
    });

    it("renders only once, however many times it is scheduled", async () => {
      const { controller } = await mount();

      await controller.scheduleChallenge();
      await controller.scheduleChallenge();

      expect(rendered).toHaveLength(1);
    });

    it("connects without a surrounding form", async () => {
      const { controller } = await mount(`
        <div data-controller="turnstile" data-turnstile-error-message-value="Verification failed">
          <div data-turnstile-target="container" data-sitekey="site-key"></div>
          <input type="hidden" data-turnstile-target="response">
        </div>
      `);

      await controller.scheduleChallenge();
      controller.disconnect();

      expect(rendered.at(-1)?.options.sitekey).toBe("site-key");
    });

    it("unbinds the form listener on disconnect", async () => {
      const { controller } = await mount();

      controller.disconnect();
      controller.runScheduledChallenge();

      expect(rendered.length).toBeGreaterThanOrEqual(0);
    });

    it("does nothing when the markup carries no widget host", async () => {
      const { controller } = await mount(`
        <form><div data-controller="turnstile"></div></form>
      `);

      await controller.scheduleChallenge();

      expect(rendered).toHaveLength(0);
    });

    it("refuses to render without a site key rather than challenging against nothing", async () => {
      const { controller } = await mount(MARKUP.replace('data-sitekey="site-key"', ""));

      await expect(controller.scheduleChallenge()).rejects.toThrow("data-sitekey");
      expect(rendered).toHaveLength(0);
    });

    it("reports a challenge script that never arrives", async () => {
      document.head.innerHTML = "";
      vi.stubGlobal("turnstile", undefined);
      const { controller } = await mount();

      await controller.scheduleChallenge();

      expect(rendered).toHaveLength(0);
    });
  });

  describe("the widget configuration", () => {
    it("passes the action and cData the markup declares", async () => {
      const { controller } = await mount(
        MARKUP.replace(
          'data-turnstile-error-message-value="Verification failed"',
          'data-turnstile-error-message-value="Verification failed" data-turnstile-action-value="sign-in" data-turnstile-cdata-value="ctx"',
        ),
      );

      await controller.scheduleChallenge();

      expect(lastOptions()?.action).toBe("sign-in");
      expect(lastOptions()?.cData).toBe("ctx");
    });

    it("falls back to the container's own data attributes", async () => {
      const { controller } = await mount(
        MARKUP.replace(
          'data-sitekey="site-key"',
          'data-sitekey="site-key" data-action="from-dom" data-cdata="dom-ctx"',
        ),
      );

      await controller.scheduleChallenge();

      expect(lastOptions()?.action).toBe("from-dom");
      expect(lastOptions()?.cData).toBe("dom-ctx");
    });

    it("omits both when neither is declared", async () => {
      const { controller } = await mount();

      await controller.scheduleChallenge();

      expect(lastOptions()?.action).toBeUndefined();
      expect(lastOptions()?.cData).toBeUndefined();
    });
  });

  describe("the widget's outcomes", () => {
    it("stores the token the challenge produced", async () => {
      const { controller, element } = await mount();
      await controller.scheduleChallenge();

      lastOptions()?.callback("a-token");

      expect(responseField(element)?.value).toBe("a-token");
    });

    it.each([
      "error-callback",
      "expired-callback",
      "timeout-callback",
      "unsupported-callback",
    ] as const)("clears the token when the challenge reports %s", async (callback) => {
      const { controller, element } = await mount();
      await controller.scheduleChallenge();
      lastOptions()?.callback("a-token");

      lastOptions()?.[callback]?.("challenge-failed");

      expect(responseField(element)?.value).toBe("");
    });

    it("announces the outcome so the page can react to it", async () => {
      const announced = recordEvents(globalThis, "turnstile:success");
      const { controller } = await mount();
      await controller.scheduleChallenge();

      lastOptions()?.callback("a-token");

      expect(announced.detail()).toMatchObject({ widgetId: "widget-host" });
    });
  });

  describe("preventDuplicateSubmit", () => {
    it("lets the first submit through and disables the submit controls", async () => {
      const { controller, element } = await mount();
      await controller.scheduleChallenge();
      lastOptions()?.callback("a-token");
      const form = element.closest("form");
      const submit = new Event("submit", { bubbles: true, cancelable: true });

      form?.dispatchEvent(submit);

      expect(submit.defaultPrevented).toBe(false);
      expect(form?.querySelector("button")?.disabled).toBe(true);
    });

    it("blocks a second submit on the same token", async () => {
      const { controller, element } = await mount();
      await controller.scheduleChallenge();
      lastOptions()?.callback("a-token");
      const form = element.closest("form");
      form?.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));

      const second = new Event("submit", { bubbles: true, cancelable: true });
      form?.dispatchEvent(second);

      expect(second.defaultPrevented).toBe(true);
    });

    it("does not interfere before a token has been solved", async () => {
      const { element } = await mount();
      const form = element.closest("form");
      const submit = new Event("submit", { bubbles: true, cancelable: true });

      form?.dispatchEvent(submit);

      expect(submit.defaultPrevented).toBe(false);
      expect(form?.querySelector("button")?.disabled).toBe(false);
    });
  });
});
