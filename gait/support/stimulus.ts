// Mounting a Stimulus controller the way the browser does.
//
// A controller is not a plain class: Stimulus constructs it with a context, defines the target and
// value properties from the `static targets`/`static values` declarations, and runs the class field
// initialisers on the way. A spec that reaches for `Object.create(Controller.prototype)` gets an
// instance with none of that -- private state reads back as `undefined` rather than its declared
// default, which silently changes which branch the code under test takes.
//
// Registering with a real `Application` costs one microtask and removes that whole class of
// difference between the spec and the page.
import { Application, type Controller, type ControllerConstructor } from "@hotwired/stimulus";
import { afterEach } from "vitest";

export type MountedController<T extends Controller> = {
  controller: T;
  element: HTMLElement;
  application: Application;
};

// One application per document. Starting a second without stopping the first leaves two mutation
// observers on the same tree, so a later spec's markup connects controllers twice.
let running: Application | null = null;

// Stopping only on the next mount would leave the last spec's observer alive into teardown, where
// its callback runs against a document whose globals are already gone.
afterEach(() => {
  running?.stop();
  running = null;
});

/**
 * Renders `html`, registers `constructor` under `identifier` and returns the instance Stimulus
 * built for the element carrying it.
 *
 * The markup must put `data-controller="<identifier>"` on the element under test and name its
 * targets and values with the same identifier.
 */
export async function mountController<T extends Controller>(
  identifier: string,
  constructor: ControllerConstructor & (abstract new (...args: never[]) => T),
  html: string,
): Promise<MountedController<T>> {
  running?.stop();

  document.body.innerHTML = html;

  const application = Application.start();
  running = application;
  application.register(identifier, constructor);

  // Stimulus connects controllers from a mutation-observer callback, which runs as a microtask.
  await Promise.resolve();

  const element = document.querySelector<HTMLElement>(`[data-controller~="${identifier}"]`);

  if (!element) {
    throw new Error(`The markup has no element carrying data-controller="${identifier}".`);
  }

  const controller = application.getControllerForElementAndIdentifier(element, identifier);

  if (!(controller instanceof constructor)) {
    throw new Error(`Stimulus did not connect a "${identifier}" controller to the element.`);
  }

  return { controller, element, application };
}
