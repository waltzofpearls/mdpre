const esbuild = require("esbuild");
const path = require("path");

const outdir = path.resolve(__dirname, "../MDPre/Resources");

esbuild
  .build({
    entryPoints: [path.resolve(__dirname, "src/editor.js")],
    bundle: true,
    minify: true,
    format: "iife",
    globalName: "MDPreEditor",
    outfile: path.join(outdir, "codemirror-editor.js"),
    target: ["safari17"],
  })
  .then(() => console.log("Build complete"))
  .catch(() => process.exit(1));
