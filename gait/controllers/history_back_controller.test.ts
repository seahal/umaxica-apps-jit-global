// The "back" link on the surfaces that do not boot React.
import { beforeEach, describe, expect, it, vi } from "vitest";

import HistoryBackController from "@/controllers/history_back_controller";

import { mountController } from "../support/stimulus";

const MARKUP = `
  <a href="/fallback" data-controller="history-back" data-action="history-back#back">Back</a>
`;

const mount = () =>
  mountController<HistoryBackController>("history-back", HistoryBackController, MARKUP);

let back: ReturnType<typeof vi.fn>;

beforeEach(() => {
  back = vi.fn();
  vi.stubGlobal("history", { length: 1, back });
});

describe("HistoryBackController", () => {
  it("goes back when there is somewhere to go back to", async () => {
    vi.stubGlobal("history", { length: 2, back });
    const { controller } = await mount();
    const event = new Event("click", { cancelable: true });

    controller.back(event);

    expect(event.defaultPrevented).toBe(true);
    expect(back).toHaveBeenCalled();
  });

  it("lets the link's own href take over when there is no history to return to", async () => {
    const { controller } = await mount();
    const event = new Event("click", { cancelable: true });

    controller.back(event);

    expect(event.defaultPrevented).toBe(false);
    expect(back).not.toHaveBeenCalled();
  });
});
