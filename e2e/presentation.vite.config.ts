import { fileURLToPath, URL } from "node:url";

import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// A test-only component fixture, separate from Rails and from every production entrypoint.
export default defineConfig({
  root: fileURLToPath(new URL("./fixtures", import.meta.url)),
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("../src", import.meta.url)) } },
  server: { host: "127.0.0.1", port: 3190, strictPort: true },
});
