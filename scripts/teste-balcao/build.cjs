const path = require("path");
const proj = "C:/Users/icaro/OneDrive/Área de Trabalho/MarlonAÇAI TOCANTINS/acaidodudu";
const esbuild = require(path.join(proj, "node_modules", "esbuild"));
const h = __dirname;
esbuild.build({
  entryPoints: [path.join(h, process.env.ENTRY || "harness.tsx")], bundle: true, platform: "node", outfile: path.join(h, process.env.OUT || "harness.cjs"), jsx: "automatic", logLevel: "error",
  external: ["jsdom"], nodePaths: [path.join(proj, "node_modules")],
  alias: { "@proj": process.env.PROJSRC || path.join(proj, "src"), "@novo": path.join(proj, "src") },
  plugins: [{ name: "stubs", setup(b) {
    // 15/10/2026: tambem o './supabaseService' importado de dentro de services/ (comandaBackend.ts)
    b.onResolve({ filter: /(services\/|^\.\/)supabaseService$/ }, () => ({ path: path.join(h, "stub-supabase.ts") }));
    b.onResolve({ filter: /services\/scaleService$/ }, () => ({ path: path.join(h, "stub-scale.ts") }));
  } }],
}).then(() => console.log("build ok")).catch(() => process.exit(1));
