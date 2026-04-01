---
name: model-download-script-update
description: Workflow command scaffold for model-download-script-update in ComfyUI-Auto_installer-PS.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /model-download-script-update

Use this workflow when working on **model-download-script-update** in `ComfyUI-Auto_installer-PS`.

## Goal

Updates or fixes to the model download scripts, typically to correct asset URLs, directory structures, filename casing, or add new download options/flags.

## Common Files

- `scripts/Download-FLUX-Models.ps1`
- `scripts/Download-HIDREAM-Models.ps1`
- `scripts/Download-LTX1-Models.ps1`
- `scripts/Download-LTX2-Models.ps1`
- `scripts/Download-QWEN-Models.ps1`
- `scripts/Download-WAN2.1-Models.ps1`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Edit one or more scripts/Download-*.ps1 files to update URLs, paths, or logic.
- Optionally update scripts/UmeAiRTUtils.psm1 if shared download logic changes.
- Optionally update README.md or docs/codemaps/backend.md to document changes.
- Commit all affected download scripts together.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.