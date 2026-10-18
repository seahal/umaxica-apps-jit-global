// Inertia application for the warp/org FQDN. It resolves pages from src/pages/warp/org only.
import { bootSurfaceInertiaApp } from "@/inertia/surface";

void bootSurfaceInertiaApp(
  import.meta.glob("../../pages/warp/org/**/*.tsx", { eager: true }),
  "warp/org",
);
