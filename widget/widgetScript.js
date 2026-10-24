// The thin on-device shell: lives in Scriptable, runs on Apple's JavaScriptCore.
// All Scriptable-specific I/O (networking, widget rendering) belongs here, kept as small as
// possible and NOT covered by the Node test harness — see widgetLogic.js/.test.js for the
// actual tested logic. Same seam as app/services/apex_client.rb vs. alk_watchdog_service.rb
// on the Rails side: this file is the untested HTTP/rendering boundary, widgetLogic.js is the
// pure, testable decision logic.

const widgetLogic = importModule('widgetLogic');

// TODO: Request() against the reef-1000 current-readings endpoint over Tailscale (issue #23),
// pass the parsed JSON into widgetLogic, and build a ListWidget from the result.
