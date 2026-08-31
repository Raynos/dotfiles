/**
 * /effort — set the session thinking level from a slash command instead of
 * shift+tab (app.thinking.cycle) / ctrl+t (app.thinking.toggle).
 *
 *   /effort           show the current level and the ladder
 *   /effort high      set a level (unambiguous prefixes ok: xhi, med, mi)
 *   /effort off       stop reasoning
 *
 * Levels mirror ThinkingLevel in @oh-my-pi/pi-agent-core; the session clamps
 * whatever you pick down to what the active model actually supports.
 */
import type { ExtensionAPI, ExtensionCommandContext } from "@oh-my-pi/pi-coding-agent";

const LEVELS = [
	{ value: "off", description: "No reasoning" },
	{ value: "minimal", description: "Very brief reasoning (~1k tokens)" },
	{ value: "low", description: "Light reasoning (~2k tokens)" },
	{ value: "medium", description: "Moderate reasoning (~8k tokens)" },
	{ value: "high", description: "Deep reasoning (~16k tokens)" },
	{ value: "xhigh", description: "Extended reasoning (~32k tokens)" },
	{ value: "max", description: "Maximum reasoning the model supports" },
] as const;

/** Resolve a level, accepting unambiguous prefixes the way `--thinking` does. */
function resolve(input: string): string | undefined {
	const value = input.trim().toLowerCase();
	if (!value) return undefined;
	const exact = LEVELS.find(level => level.value === value);
	if (exact) return exact.value;
	// Two-character minimum, matching getOwnSelector() in src/thinking.ts.
	if (value.length < 2) return undefined;
	const matches = LEVELS.filter(level => level.value.startsWith(value));
	return matches.length === 1 ? matches[0].value : undefined;
}

export default function effortCommand(pi: ExtensionAPI) {
	const handler = async (args: string, ctx: ExtensionCommandContext) => {
		const current = pi.getThinkingLevel() ?? "inherit";

		if (!args.trim()) {
			const ladder = LEVELS.map(level => (level.value === current ? `[${level.value}]` : level.value)).join(" · ");
			ctx.ui.notify(`Thinking: ${current}\n${ladder}`, "info");
			return;
		}

		const level = resolve(args);
		if (!level) {
			ctx.ui.notify(
				`Unknown thinking level: ${args.trim()} — try ${LEVELS.map(level => level.value).join(", ")}`,
				"error",
			);
			return;
		}

		pi.setThinkingLevel(level as Parameters<typeof pi.setThinkingLevel>[0]);
		ctx.ui.notify(`Thinking: ${current} → ${level}`, "info");
	};

	const options = {
		description: "Set the reasoning effort (off|minimal|low|medium|high|xhigh|max)",
		getArgumentCompletions: (argumentPrefix: string) =>
			LEVELS.filter(level => level.value.startsWith(argumentPrefix.trim().toLowerCase())).map(level => ({
				value: level.value,
				label: level.value,
				description: level.description,
			})),
		handler,
	};

	pi.registerCommand("effort", options);
}
