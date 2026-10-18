// The confirm-before-leaving guard on forms that do not boot React.
import { beforeEach, describe, expect, it, vi } from "vitest";

import UnsavedChangesController from "@/controllers/unsaved_changes_controller";

import { mountController } from "../support/stimulus";

const MESSAGE = "Unsaved changes!";

const MARKUP = `
  <form data-controller="unsaved-changes" data-unsaved-changes-message-value="${MESSAGE}">
    <input type="text" name="title">
  </form>
`;

const mount = (html = MARKUP) =>
  mountController<UnsavedChangesController>("unsaved-changes", UnsavedChangesController, html);

const typeInto = (element: HTMLElement) => {
  element.querySelector("input")?.dispatchEvent(new Event("input", { bubbles: true }));
};

let confirmed: boolean;

beforeEach(() => {
  confirmed = true;
  vi.stubGlobal(
    "confirm",
    vi.fn(() => confirmed),
  );
});

describe("UnsavedChangesController", () => {
  describe("while the form is untouched", () => {
    it("lets a Turbo visit through", async () => {
      const { controller } = await mount();
      const visit = new Event("turbo:before-visit", { cancelable: true });

      controller.handleBeforeVisit(visit);

      expect(visit.defaultPrevented).toBe(false);
      expect(globalThis.confirm).not.toHaveBeenCalled();
    });

    it("lets the page unload without a prompt", async () => {
      const { controller } = await mount();
      const unload = new Event("beforeunload", { cancelable: true });

      controller.handleBeforeUnload(unload);

      expect(unload.defaultPrevented).toBe(false);
    });
  });

  describe("once the form has been edited", () => {
    it("asks before a Turbo visit and lets it through when the visitor agrees", async () => {
      const { controller, element } = await mount();
      typeInto(element);
      const visit = new Event("turbo:before-visit", { cancelable: true });

      controller.handleBeforeVisit(visit);

      expect(globalThis.confirm).toHaveBeenCalledWith(MESSAGE);
      expect(visit.defaultPrevented).toBe(false);
    });

    it("cancels the visit when the visitor declines", async () => {
      confirmed = false;
      const { controller, element } = await mount();
      typeInto(element);
      const visit = new Event("turbo:before-visit", { cancelable: true });

      controller.handleBeforeVisit(visit);

      expect(visit.defaultPrevented).toBe(true);
    });

    it("blocks the unload so the browser shows its own prompt", async () => {
      const { controller, element } = await mount();
      typeInto(element);
      const unload = new Event("beforeunload", { cancelable: true });

      controller.handleBeforeUnload(unload);

      expect(unload.defaultPrevented).toBe(true);
    });

    it("stops guarding once the form has been submitted", async () => {
      const { controller, element } = await mount();
      typeInto(element);
      element.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
      const visit = new Event("turbo:before-visit", { cancelable: true });

      controller.handleBeforeVisit(visit);

      expect(globalThis.confirm).not.toHaveBeenCalled();
      expect(visit.defaultPrevented).toBe(false);
    });

    it("treats a change on a select or checkbox as an edit too", async () => {
      const { controller, element } = await mount();
      element.querySelector("input")?.dispatchEvent(new Event("change", { bubbles: true }));
      const visit = new Event("turbo:before-visit", { cancelable: true });

      controller.handleBeforeVisit(visit);

      expect(globalThis.confirm).toHaveBeenCalled();
    });

    it("falls back to its own copy when the markup names no message", async () => {
      const bare = `
        <form data-controller="unsaved-changes"><input type="text"></form>
      `;
      const { controller, element } = await mount(bare);
      typeInto(element);

      controller.handleBeforeVisit(new Event("turbo:before-visit", { cancelable: true }));

      expect(globalThis.confirm).toHaveBeenCalledWith("変更は保存されていません。移動しますか？");
    });
  });

  describe("disconnect", () => {
    it("stops guarding a form that is no longer on the page", async () => {
      const { controller, element, application } = await mount();
      typeInto(element);

      application.stop();
      controller.disconnect();
      const visit = new Event("turbo:before-visit", { cancelable: true });
      document.dispatchEvent(visit);

      expect(visit.defaultPrevented).toBe(false);
    });
  });
});
