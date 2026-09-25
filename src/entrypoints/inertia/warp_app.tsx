// Inertia application for the warp/app FQDN. It resolves pages from src/pages/warp/app only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/warp/app/**/*.tsx", { eager: true }),
  "warp/app",
);
