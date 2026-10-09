import { isValidElement, type ReactNode } from "react";
import type { createRoot as realCreateRoot } from "react-dom/client";
import { afterEach, describe, expect, it, vi } from "vitest";

import { present } from "../support/present";

// Typed from React's own export, so what the spec reads back off a recorded `render` call is the
// element React would have been handed rather than an `any`.
const render = vi.fn<ReturnType<typeof realCreateRoot>["render"]>();
const unmount = vi.fn<ReturnType<typeof realCreateRoot>["unmount"]>();
const createRoot = vi.fn(() => ({ render, unmount }));

/** The props of the element the island root was asked to render. */
function renderedProps(index: number): unknown {
  const [node]: [ReactNode] = present(render.mock.calls[index], `render call ${index}`);

  if (!isValidElement(node)) {
    throw new Error("The island root was rendered something that is not a React element.");
  }

  return node.props;
}

vi.mock("react-dom/client", () => {
  return {
    createRoot,
  };
});

vi.mock("@/features/ui_gallery/UiGallery", () => {
  return {
    UiGallery: () => null,
  };
});

describe("react islands", () => {
  afterEach(() => {
    document.body.innerHTML = "";
    createRoot.mockClear();
    render.mockClear();
    unmount.mockClear();
  });

  it("mounts known islands and parses JSON props", async () => {
    const container = document.createElement("div");
    container.innerHTML = `
      <div data-react-component="UiGallery" data-react-props='{"title":"Probe"}'></div>
    `;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(createRoot).toHaveBeenCalledTimes(1);
    expect(render).toHaveBeenCalledTimes(1);
    expect(renderedProps(0)).toMatchObject({ title: "Probe" });
  });

  it("silently skips unknown island names", async () => {
    const container = document.createElement("div");
    container.innerHTML = `
      <div data-react-component="UnknownIsland" data-react-props='{"title":"Ignored"}'></div>
    `;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(createRoot).not.toHaveBeenCalled();
    expect(render).not.toHaveBeenCalled();
  });

  it("silently skips an element with an empty component name", async () => {
    const container = document.createElement("div");
    container.innerHTML = `<div data-react-component=""></div>`;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(createRoot).not.toHaveBeenCalled();
  });

  it("does not remount an element that is already mounted", async () => {
    const container = document.createElement("div");
    container.innerHTML = `<div data-react-component="UiGallery"></div>`;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);
    mountReactIslands(document);

    expect(createRoot).toHaveBeenCalledTimes(1);
  });

  it("falls back to empty props for a value that is not valid JSON", async () => {
    const container = document.createElement("div");
    container.innerHTML = `
      <div data-react-component="UiGallery" data-react-props="not-json"></div>
    `;
    document.body.append(container);

    const { mountReactIslands } = await import("../../src/entrypoints/react_islands");

    mountReactIslands(document);

    expect(renderedProps(0)).toEqual({});
  });

  it("falls back to empty props for JSON that parses to an array or null", async () => {
    const { parseReactIslandProps } = await import("../../src/entrypoints/react_islands");

    expect(parseReactIslandProps("[1,2,3]")).toEqual({});
    expect(parseReactIslandProps("null")).toEqual({});
  });

  it("registers turbo:load/turbo:before-cache listeners once and mounts/unmounts islands", async () => {
    vi.resetModules();

    const container = document.createElement("div");
    container.innerHTML = `<div data-react-component="UiGallery"></div>`;
    document.body.append(container);

    const { registerReactIslands } = await import("../../src/entrypoints/react_islands");

    registerReactIslands();

    expect(createRoot).toHaveBeenCalledTimes(1);

    document.dispatchEvent(new Event("turbo:before-cache"));

    expect(unmount).toHaveBeenCalledTimes(1);

    createRoot.mockClear();
    document.dispatchEvent(new Event("turbo:load"));

    expect(createRoot).toHaveBeenCalledTimes(1);

    // A second call with listeners already registered mounts directly instead of
    // re-registering the turbo:load/turbo:before-cache listeners. Unmount first so the
    // element is eligible to be mounted again.
    document.dispatchEvent(new Event("turbo:before-cache"));
    createRoot.mockClear();
    registerReactIslands();

    expect(createRoot).toHaveBeenCalledTimes(1);

    // Registering a second time did not add a second turbo:load listener.
    createRoot.mockClear();
    document.dispatchEvent(new Event("turbo:before-cache"));
    document.dispatchEvent(new Event("turbo:load"));

    expect(createRoot).toHaveBeenCalledTimes(1);
  });
});
