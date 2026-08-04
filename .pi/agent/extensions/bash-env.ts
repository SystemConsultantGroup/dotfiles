import { existsSync } from "node:fs";
import { join, sep } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createBashTool } from "@earendil-works/pi-coding-agent";

// Find a marker file in cwd or any ancestor, mirroring direnv/devenv lookup.
function findUp(cwd: string, names: string[]): string | undefined {
	let dir = cwd;
	for (;;) {
		for (const name of names) {
			if (existsSync(join(dir, name))) return join(dir, name);
		}
		if (dir === sep) return undefined;
		const parent = dir.slice(0, dir.lastIndexOf(sep)) || sep;
		if (parent === dir) return undefined;
		dir = parent;
	}
}

// Single-quote a string so it embeds safely in `bash -c '...'`.
function shq(s: string): string {
	return "'" + s.replace(/'/g, "'\\''") + "'";
}

const envrcMarker = [".envrc"];
const devenvMarkers = ["devenv.nix", "devenv.yaml"];

// Which wrapping applies to commands run under `cwd`, mirroring spawnHook.
function wrapKind(cwd: string): "direnv" | "devenv" | undefined {
	if (findUp(cwd, envrcMarker)) return "direnv";
	if (findUp(cwd, devenvMarkers)) return "devenv";
	return undefined;
}

const wrapNotes: Record<string, string> = {
	direnv:
		"The bash tool injects `eval \"$(direnv export bash)\"` before every command run in a directory containing a .envrc, so direnv-managed env vars are loaded in non-login shells.",
	devenv:
		"The bash tool wraps every command run in a directory containing devenv.nix/devenv.yaml with `devenv shell -- bash -c ...`, so devenv-managed packages and env vars are available (falling back to running bare if devenv is not installed).",
};

export default function (pi: ExtensionAPI) {
	const bashTool = createBashTool(process.cwd(), {
		spawnHook: ({ command, cwd, env }) => {
			switch (wrapKind(cwd)) {
				case "direnv":
					return {
						// No-op (and safe) when .envrc is missing, blocked, or direnv absent.
						command: `eval "$(direnv export bash 2>/dev/null)"\n${command}`,
						cwd,
						env,
					};
				case "devenv": {
					const wrapped = [
						"if command -v devenv >/dev/null 2>&1; then",
						`	devenv shell -- bash -c ${shq(command)}`,
						"else",
						`	${command}`,
						"fi",
					].join("\n");
					return { command: wrapped, cwd, env };
				}
				default:
					return { command, cwd, env };
			}
		},
	});

	pi.registerTool({
		...bashTool,
		execute: async (id, params, signal, onUpdate, _ctx) => {
			return bashTool.execute(id, params, signal, onUpdate);
		},
	});

	// Explain the wrapping in the system prompt when the session cwd is affected.
	pi.on("before_agent_start", async (event) => {
		const kind = wrapKind(event.systemPromptOptions.cwd);
		const note = kind && wrapNotes[kind];
		if (!note) return;
		return {
			systemPrompt: `${event.systemPrompt}\n\n## Bash tool wrapping\n${note}`,
		};
	});
}
