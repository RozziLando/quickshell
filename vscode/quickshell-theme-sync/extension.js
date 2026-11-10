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
        return null;
    }
}

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

function vscodeThemeOf(dir, id) {
    const t = readJson(path.join(dir, "themes", id + ".json"));
    return t && t.vscode && t.vscode.theme ? t.vscode : null;
}

let lastId = null;
const warned = new Set();

async function sync(force) {
    if (!config().get("enabled", true)) return;
    const dir = shellDir();
    const settings = readJson(path.join(dir, "theme.json"));
    if (!settings || !settings.theme) return;
    if (settings.vscodeThemeSync === false) { lastId = null; return; }
    if (settings.theme === lastId && !force) return;
    lastId = settings.theme;

    const target = vscodeThemeOf(dir, settings.theme);
    if (!target) return;

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
            watcher = fs.watch(dir, (event, name) => {
                if (!name || name === "theme.json") later(false);
            });
            watcher.on("error", () => { unwatch(); poll(); });
        } catch (e) {
            poll();
        }
    }
    function poll() {
        polling = path.join(dir, "theme.json");
        fs.watchFile(polling, { interval: 5000 }, () => {
            later(false);
            if (!watcher && fs.existsSync(dir)) watch();
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
        later(true);
    }));
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e => {
        if (!e.affectsConfiguration("quickshellThemeSync")) return;
        if (e.affectsConfiguration("quickshellThemeSync.shellDir")) watch();
        later(true);
    }));
    context.subscriptions.push(vscode.commands.registerCommand(
        "quickshellThemeSync.syncNow", () => { themeLabels = null; return sync(true); }));

    later(true, 0);
}

function deactivate() {}

module.exports = { activate, deactivate };
