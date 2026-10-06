import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(rootDir, "..");

// GitHub Pages project site lives under /ZeroEchelon/; Cloudflare Pages uses /.
const base = process.env.GITHUB_PAGES === "1" ? "/ZeroEchelon/" : "/";

export default defineConfig({
  root: rootDir,
  base,
  server: {
    fs: {
      allow: [repoRoot],
    },
  },
  resolve: {
    alias: {
      "@protocol": path.resolve(repoRoot, "protocol"),
    },
  },
});
