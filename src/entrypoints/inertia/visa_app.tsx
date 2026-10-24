// Inertia application for the visa/app FQDN. It resolves only the Visa app page directory.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/visa/app/**/*.tsx", { eager: true }),
  "visa/app",
);
