// Quickshell Theme Sync
//
// Follows the Quickshell island theme. The shell keeps the active theme in
// theme.json ("theme": "<id>") and every theme file, themes/<id>.json,
// says which VS Code theme matches it:
//
//   "vscode": { "theme": "Dracula Theme", "extension": "dracula-theme.theme-dracula" }
//
// When the theme in theme.json changes (picked in the shell launcher, or
// "qs ipc call theme set <id>") this sets workbench.colorTheme. VS Code
// writes the setting itself, so comments in settings.json are kept.
// Plain JavaScript, no dependencies, no build step.
//
// "vscodeThemeSync": false in theme.json (or the VS Code setting
// quickshellThemeSync.enabled) turns it off.
//
// Kept cheap: no polling (the folder is watched by the system, inotify),
// theme.json is the only file read on a change, and only when the theme id
// differs from the last one is anything else done (the theme file read,
// the setting written). Other changes to
// theme.json (scale, auto-hide...) leave VS Code alone, so a theme picked by
// hand in VS Code stays until the next shell theme change.

const vscode = require("vscode");
const fs = require("fs");
const path = require("path");
const os = require("os");

function config() {
    return vscode.workspace.getConfiguration("quickshellThemeSync");
}

function shellDir() {
    const dir = config().get("shellDir") || "~/.config/quickshell";
    return dir.replace(/^~(?=$|\/)/, os.homedir());
}

function readJson(file) {
    try {
        return JSON.parse(fs.readFileSync(file, "utf8"));
    } catch (e) {
        return null;    // missing, or written halfway: the next change retries
    }
}

// Labels of the installed color themes; rebuilt only when extensions are
// installed or removed
let themeLabels = null;
function installedThemes() {
    if (!themeLabels) {
        themeLabels = new Set();
        for (const ext of vscode.extensions.all) {
            const themes = ((ext.packageJSON || {}).contributes || {}).themes || [];
            for (const t of themes) themeLabels.add(t.label || t.id);
        }
    }
    return themeLabels;
}

// Shell theme id -> VS Code theme ({ theme, extension }). Read every time
// the theme changes (one small file, only then): an edited themes/<id>.json
// is seen at once
function vscodeThemeOf(dir, id) {
    const t = readJson(path.join(dir, "themes", id + ".json"));
    return t && t.vscode && t.vscode.theme ? t.vscode : null;
}

// Last shell theme handled: same id again = nothing to do
let lastId = null;
// Missing themes are reported once per session, not at every change
const warned = new Set();

// force: also when the id did not change (startup, settings, command)
async function sync(force) {
    if (!config().get("enabled", true)) return;
    const dir = shellDir();
    const settings = readJson(path.join(dir, "theme.json"));
    if (!settings || !settings.theme) return;
    // "vscodeThemeSync": false in theme.json: VS Code keeps its theme. When
    // it is turned on again the current shell theme is applied at once
    if (settings.vscodeThemeSync === false) { lastId = null; return; }
    if (settings.theme === lastId && !force) return;
    lastId = settings.theme;

    const target = vscodeThemeOf(dir, settings.theme);
    if (!target) return;     // this shell theme has no VS Code theme

    const workbench = vscode.workspace.getConfiguration("workbench");
    if (workbench.get("colorTheme") === target.theme) return;

    if (!installedThemes().has(target.theme)) {
        if (!warned.has(target.theme)) {
            warned.add(target.theme);
            vscode.window.showWarningMessage(
                `Quickshell theme "${settings.theme}": VS Code theme "${target.theme}" is not installed`
                + (target.extension ? ` (extension ${target.extension}).` : "."));
        }
        return;
    }

    // The setting is global: with several VS Code windows open, one write is
    // enough. The focused window writes at once; the others (each window has
    // its own extension process) wait a different short time and skip the
    // write if another window already did it
    if (!vscode.window.state.focused) {
        await new Promise(r => setTimeout(r, 40 + (process.pid % 8) * 40));
        if (vscode.workspace.getConfiguration("workbench").get("colorTheme") === target.theme) return;
    }
    await vscode.workspace.getConfiguration("workbench")
        .update("colorTheme", target.theme, vscode.ConfigurationTarget.Global);
}

function activate(context) {
    let timer = null;
    let forced = false;
    // The shell writes theme.json in one go, but a couple of events may
    // arrive for it: one sync
    const later = (force, delay) => {
        forced = forced || !!force;
        clearTimeout(timer);
        timer = setTimeout(() => {
            const f = forced;
            forced = false;
            sync(f).catch(() => {});
        }, delay === undefined ? 60 : delay);
    };

    let dir = shellDir();
    let watcher = null;
    let polling = null;

    function watch() {
        unwatch();
        dir = shellDir();
        try {
            // Folder, not file: still works when theme.json is replaced
            watcher = fs.watch(dir, (event, name) => {
                if (!name || name === "theme.json") later(false);
            });
            watcher.on("error", () => { unwatch(); poll(); });
        } catch (e) {
            poll();     // folder missing or not watchable: slow check instead
        }
    }
    // Only when the folder cannot be watched
    function poll() {
        polling = path.join(dir, "theme.json");
        fs.watchFile(polling, { interval: 5000 }, () => {
            later(false);
            if (!watcher && fs.existsSync(dir)) watch();   // folder back: watch it
        });
    }
    function unwatch() {
        if (watcher) { watcher.close(); watcher = null; }
        if (polling) { fs.unwatchFile(polling); polling = null; }
    }
    watch();

    context.subscriptions.push({ dispose() { clearTimeout(timer); unwatch(); } });
    context.subscriptions.push(vscode.extensions.onDidChange(() => {
        themeLabels = null;
        later(true);    // a missing theme may have been installed now
    }));
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e => {
        if (!e.affectsConfiguration("quickshellThemeSync")) return;
        if (e.affectsConfiguration("quickshellThemeSync.shellDir")) watch();
        later(true);
    }));
    context.subscriptions.push(vscode.commands.registerCommand(
        "quickshellThemeSync.syncNow", () => { themeLabels = null; return sync(true); }));

    later(true, 0);    // at startup: the theme the shell has now
}

function deactivate() {}

module.exports = { activate, deactivate };
