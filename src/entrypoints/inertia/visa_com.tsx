// Inertia application for the visa/com FQDN. It resolves only the Visa com page directory.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/visa/com/**/*.tsx", { eager: true }),
  "visa/com",
);
