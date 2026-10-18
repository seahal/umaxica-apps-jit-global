import { createElement } from "react";
import { createRoot } from "react-dom/client";

import { UiGallery } from "../../src/features/ui_gallery/UiGallery";

import "../../src/styles/surfaces/auth_app.css";

const root = document.querySelector("#fixture");
if (!root) {
  throw new Error("The presentation fixture root is missing.");
}
createRoot(root).render(createElement(UiGallery));
