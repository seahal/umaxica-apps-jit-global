import { fileURLToPath } from "node:url";

import inertia from "@inertiajs/vite";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import RubyPlugin from "vite-plugin-ruby";

const srcRoot = fileURLToPath(new URL("./src", import.meta.url));

export default defineConfig({
  plugins: [RubyPlugin(), tailwindcss(), inertia(), react()],
  server: {
    // Development is also reached through the public app/com/org hostnames. Keep Vite's
    // DNS-rebinding protection enabled while allowing only domains owned by this deployment.
    allowedHosts: [".umaxica.app", ".umaxica.com", ".umaxica.org"],
  },
  resolve: {
    // One alias, matching `paths` in tsconfig.app.json. Every additional alias is a second
    // spelling for a path TypeScript and Vite must both agree on, so they are kept to one.
    alias: { "@": srcRoot },
  },
  build: {
    // `vite-plugin-ruby` sets `sourcemap: !isLocal`, so every non-development build emitted a
    // `//# sourceMappingURL=` comment next to the chunk. The built assets are served from a
    // separate asset host (`config.asset_host`, production.rb), so that comment publishes the
    // original TypeScript — file paths, comments, and the reasoning in them — to anyone who loads
    // a page. `hidden` keeps the `.map` files, which an error monitor still needs, and drops only
    // the pointer that advertises them to the browser.
    //
    // The maps are a build artifact, not a browser-public asset: whatever uploads `public/vite`
    // to the asset host must exclude `*.map`. `vite-plugin-ruby` spreads `...userConfig.build`
    // after its own defaults, so this wins.
    sourcemap: "hidden",
  },
});
