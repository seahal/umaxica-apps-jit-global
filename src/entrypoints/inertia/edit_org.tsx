// Inertia application for the edit/org FQDN. It resolves pages from src/pages/edit/org only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/edit/org/**/*.tsx", { eager: true }),
  "edit/org",
);
