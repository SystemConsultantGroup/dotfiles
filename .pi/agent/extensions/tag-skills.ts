// @ts-nocheck

import { dirname } from "node:path";
import { readFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const TAGS = new Set(["delegate", "brainstorm", "plan"]);
const TAG_PREFIX = /^\[([^\]]+)\]\s*:\s*([\s\S]*)$/;

function stripFrontmatter(content: string): string {
	return content.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, "").trim();
}

export default function (pi: ExtensionAPI) {
	pi.on("input", (event, ctx) => {
		if (event.source === "extension") return { action: "continue" };

		const match = event.text.match(TAG_PREFIX);
		if (!match) return { action: "continue" };

		const tagNames = match[1]
			.split(",")
			.map((tag) => tag.trim())
			.filter(Boolean);
		if (tagNames.length === 0 || tagNames.some((tag) => !TAGS.has(tag))) {
			ctx.ui.notify(`Unknown tag. Use: ${[...TAGS].join(", ")}`, "warning");
			return { action: "continue" };
		}

		const skills = pi
			.getCommands()
			.filter((command) => command.source === "skill" && TAGS.has(command.name))
			.reduce(
				(found, command) => found.set(command.name, command.sourceInfo.path),
				new Map<string, string>(),
			);
		const blocks = tagNames.map((tag) => {
			const path = skills.get(tag);
			if (!path) return undefined;

			const content = stripFrontmatter(readFileSync(path, "utf8"));
			return `<skill name="${tag}" location="${path}">\nReferences are relative to ${dirname(path)}.\n\n${content}\n</skill>`;
		});

		if (blocks.some((block) => !block)) {
			ctx.ui.notify(
				"A requested tag skill is not loaded; sending the message unchanged.",
				"warning",
			);
			return { action: "continue" };
		}

		return {
			action: "transform",
			text: `${blocks.join("\n\n")}\n\n${match[2]}`,
		};
	});
}
