// Inertia application for the auth/app FQDN. It resolves pages from src/pages/auth/app only.
import { router } from "@inertiajs/react";

import { bootSurfaceInertiaApp } from "@/inertia/surface";

const phaseBoundSignInEntryPaths = new Set([
  "/sign/in/email/new",
  "/sign/in/email/edit",
  "/sign/in/secret/new",
]);

router.on("navigate", (event) => {
  if (event.detail.type !== "history") {
    return;
  }

  const target = new URL(event.detail.page.url, window.location.origin);
  if (phaseBoundSignInEntryPaths.has(target.pathname)) {
    window.location.reload();
  }
});

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/auth/app/**/*.tsx", { eager: true }),
  "auth/app",
);
