import { describe, expect, it } from "bun:test";
import * as path from "node:path";
import { initLoaderContext } from "../native/loader-state.js";

describe("Android addon resolution", () => {
	it("never selects a glibc addon or an x86 CPU variant for Android ARM64", () => {
		const context = initLoaderContext({
			platform: "android",
			arch: "arm64",
			nativeDir: "/workspace/native",
			isCompiledBinary: false,
		});
		expect(context.addonFilenames).toEqual(["pi_natives.android-arm64.node"]);
		expect(context.selectedVariant).toBeNull();
		expect(context.candidates).toContain("/workspace/native/pi_natives.android-arm64.node");
		expect(context.candidates.every(candidate => path.basename(candidate) === "pi_natives.android-arm64.node")).toBe(
			true,
		);
	});

	it("uses the versioned extraction directory for the compiled Android executable", () => {
		const context = initLoaderContext({
			platform: "android",
			arch: "arm64",
			nativeDir: "/workspace/native",
			isCompiledBinary: true,
		});
		expect(context.candidates[0]).toBe(path.join(context.versionedDir, "pi_natives.android-arm64.node"));
		expect(context.stageFromNodeModules).toBe(false);
	});
});
