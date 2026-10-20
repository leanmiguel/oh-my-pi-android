import * as path from "node:path";
import { createRequire } from "node:module";
import { compileCodingAgent } from "../packages/coding-agent/scripts/compile-binary";

const repoRoot = path.resolve(import.meta.dir, "..");
const executablePath = process.env.OMP_ANDROID_BUN;
if (!executablePath) throw new Error("Set OMP_ANDROID_BUN to the official Android ARM64 Bun executable");
const require_ = createRequire(import.meta.url);
const transformers: { version: string } = require_("@huggingface/transformers/package.json");
await compileCodingAgent({
	repoRoot,
	entrypoint: path.join(repoRoot, "packages/coding-agent/src/cli.ts"),
	outfile: path.join(repoRoot, "android/dist/omp"),
	executablePath,
	// Bun 1.4.3 supports this target; the workspace's Bun types predate its addition.
	target: "bun-linux-arm64-android" as Bun.Build.CompileTarget,
	transformersVersion: transformers.version,
	native: { platform: "android", arch: "arm64" },
	bytecode: false,
	minifyIdentifiers: true,
});
