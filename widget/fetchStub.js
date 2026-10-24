// The actual file that lives in Scriptable on-device (iCloud Drive/Scriptable/). Its only job is
// to pull the current widgetScript.js off this repo's main branch and run it, so updates ship by
// committing here rather than re-copying a file onto the phone. See the repo's README/CLAUDE.md
// for why this mirrors the deploy pipeline's own pull-based philosophy.

// TODO: Request() the raw GitHub URL for widget/widgetScript.js (and its importModule'd
// widgetLogic.js, if that isn't inlined), then eval the result.
