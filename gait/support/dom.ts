// Reading and driving the markup a controller was mounted on.
//
// Each reader answers or throws rather than returning `undefined` for the caller to branch on: a
// spec that silently skipped its own assertion because a selector stopped matching is worse than
// one that fails naming the selector.
export function requireElement(root: ParentNode, selector: string): HTMLElement {
  const element = root.querySelector<HTMLElement>(selector);

  if (!element) {
    throw new Error(`The markup carries no element matching ${selector}.`);
  }

  return element;
}

export function requireInput(root: ParentNode, selector: string): HTMLInputElement {
  const element = requireElement(root, selector);

  if (!(element instanceof HTMLInputElement)) {
    throw new Error(`The element matching ${selector} is not an input.`);
  }

  return element;
}

/**
 * The text an element actually names through `aria-describedby`, resolved id by id.
 *
 * Asserting on the resolved text rather than on the attribute is what proves the association: an
 * `aria-describedby` pointing at an id nothing carries announces nothing.
 */
export function describedByText(element: Element): string {
  return (element.getAttribute("aria-describedby") ?? "")
    .split(" ")
    .filter(Boolean)
    .map((id) => document.querySelector(`#${id}`)?.textContent ?? "")
    .join(" ");
}
