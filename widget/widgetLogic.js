// Pure logic for the current-readings widget: no Scriptable globals (Request, ListWidget, etc.)
// allowed in this file, so it can be both `require`'d by Node tests and `importModule`'d
// unmodified by Scriptable on-device (Scriptable shims `module.exports` the same way Node does).
//
// The thin on-device shell (widgetScript.js) is responsible for fetching the JSON and rendering
// a ListWidget; everything in here should be a plain function of plain data.

// TODO: fill in once the Rails endpoint's response shape (issue #23) is settled.

module.exports = {};
