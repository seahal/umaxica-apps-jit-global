import { Controller, type ControllerConstructor } from "@hotwired/stimulus";

import { application } from "./application";

// The glob is a literal so Vite can rewrite it, and it matches the controller file extension. A
// module in this directory that does not default-export a Controller subclass would silently never
// register, which is indistinguishable from the controller not existing; it is reported instead.
const controllers = import.meta.glob("./**/*_controller.ts", { eager: true });

function isControllerConstructor(value: unknown): value is ControllerConstructor {
  return typeof value === "function" && value.prototype instanceof Controller;
}

for (const [path, module] of Object.entries(controllers)) {
  const controllerName = path
    .replace("./", "")
    .replace("_controller.ts", "")
    .replaceAll("_", "-")
    .replaceAll("/", "--");

  /* v8 ignore start -- the glob only matches controller files that default-export a subclass */
  const constructor =
    typeof module === "object" && module !== null && "default" in module ? module.default : null;

  if (!isControllerConstructor(constructor)) {
    throw new Error(`Stimulus controller ${path} does not default-export a Controller subclass.`);
  }
  /* v8 ignore stop */

  application.register(controllerName, constructor);
}
