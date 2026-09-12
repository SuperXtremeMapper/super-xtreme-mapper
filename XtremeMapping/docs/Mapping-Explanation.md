> The main interface is now [Assistant](Unified-Assistant.md). Open **Assistant → Reference guide / Export…** for the local guide; questions and reviewed edits share the main conversation. The notes below describe the explanation foundation.

# Mapping explanation and reference guides

Open **Explain…** above the mapping table. This is a read-only workspace: exploring facts, asking questions and exporting documentation do not change your TSI, mark it saved, or create an Undo step.

## Reference guide

The default view is a complete, local reference guide. It covers every device and mapping row, identifies unknown portions, and includes the configured controller evidence where available. Use **Export guide…** for Markdown, plain text or a paginated PDF. Review the content before export and choose a new file. No API key is required.

The guide describes mapping settings, not live controller state. It keeps physical controller layers, MIDI channels, Traktor decks and modifier conditions separate. Missing controller profiles, unknown custom maps and opaque MIDI data are explicit limitations. A documented address is not a claim of hardware testing.

## Questions

Switch to **Questions**, enter a command, control name, MIDI address or modifier question, and choose **Find locally**. Matching source rows remain available without AI. Click a row to return to it in the editor. With rows already selected, you can include those rows first and limit lookup to their devices.

To request an explanation, add your Anthropic key through the existing key settings, enable AI for this sheet session, and choose **Ask AI**. The request sends the question plus a bounded set of relevant row facts, including device names and comments, commands, MIDI settings, conditions and profile evidence. It excludes the original TSI/XML preservation data and full manuals. API usage may incur charges. Local guides, search and exports never require a network request.

Model selection is separate from Voice Learn. The initial choices are Sonnet 5 and Haiku 4.5, with Sonnet selected by default. Model IDs and transport requirements were checked against [Anthropic's model catalogue](https://platform.claude.com/docs/en/models/overview) and [Messages API](https://platform.claude.com/docs/en/api/messages/create). These documented options are not a claim of a live quality benchmark on your mappings.

AI answers separate supplied facts, interpretations and unknowns. Reference buttons lead to the rows used for that answer; references outside the supplied context are rejected. Review wording against the source rows: a valid reference does not independently prove the model's interpretation. **Export explanation…** exports the displayed answer separately from the complete reference guide.

Changing the mapping, including profile metadata or Undo, invalidates the previous snapshot and answer. Changing a question, model or AI opt-in cancels the current answer. Closing the sheet cancels outstanding work; late results cannot become current. The assistant has no editing, filesystem, browsing or command-execution tools.

## Limits and uncertainty

Questions are limited to 4000 characters. Each request uses up to 80 rows and 96 KiB of context, and reports omitted rows or shortened facts. Large mappings remain fully represented in the reference guide; a partial answer must not be treated as a whole-document audit. Responses are limited to 4096 output tokens and 1 MiB of received data. Missing credentials, rate limits, refusal, truncated output and malformed references are reported without applying changes. Requests are not retried automatically.

The controller catalogue currently covers Xone K1/K2/K3. Generic MIDI mappings remain explainable without a profile. Conversational edits, AI import repair and Euphonia are later milestones.
