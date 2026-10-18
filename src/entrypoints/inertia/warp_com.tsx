// Inertia application for the warp/com FQDN. It resolves pages from src/pages/warp/com only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/warp/com/**/*.tsx", { eager: true }),
  "warp/com",
);
