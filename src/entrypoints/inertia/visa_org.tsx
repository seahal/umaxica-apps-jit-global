// Inertia application for the visa/org FQDN. It resolves only the Visa org page directory.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/visa/org/**/*.tsx", { eager: true }),
  "visa/org",
);
