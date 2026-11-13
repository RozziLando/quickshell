const vscode = require("vscode");
const fs = require("fs");
const path = require("path");
const os = require("os");
const generator = require("./generator");

const CUSTOM = "Quickshell Custom";

function config() {
    return vscode.workspace.getConfiguration("quickshellThemeSync");
}

function shellDir() {
    const dir = config().get("shellDir") || "~/.config/quickshell";
    return dir.replace(/^~(?=$|\/)/, os.homedir());
}

function readText(file) {
    try {
        return fs.readFileSync(file, "utf8");
    } catch (e) {
        return null;
    }
}

function parseJsonc(text) {
    let out = "", inString = false;
    for (let i = 0; i < text.length; i++) {
        const ch = text[i];
        if (inString) {
            out += ch;
            if (ch === "\\") { out += text[++i] || ""; continue; }
            if (ch === "\"") inString = false;
            continue;
        }
        if (ch === "\"") { inString = true; out += ch; continue; }
        if (ch === "/" && text[i + 1] === "/") {
            while (i < text.length && text[i] !== "\n") i++;
            out += "\n";
            continue;
        }
        if (ch === "/" && text[i + 1] === "*") {
            const end = text.indexOf("*/", i + 2);
            i = end < 0 ? text.length : end + 1;
            continue;
        }
        out += ch;
    }
    return JSON.parse(out.replace(/^﻿/, "").replace(/,(\s*[}\]])/g, "$1"));
}

function readJson(file) {
    const text = readText(file);
    if (text === null) return null;
    try {
        return JSON.parse(text);
    } catch (e) {
        try {
            return parseJsonc(text);
        } catch (e2) {
            return null;
        }
    }
}

const validity = new Map();
function validTheme(file) {
    let stat;
    try {
        stat = fs.statSync(file);
    } catch (e) {
        return false;
    }
    const key = stat.mtimeMs + ":" + stat.size;
    const known = validity.get(file);
    if (known && known.key === key) return known.ok;
    const theme = readJson(file);
    const ok = !!(theme && (theme.colors || theme.tokenColors));
    validity.set(file, { key, ok });
    return ok;
}

function colorTheme() {
    return vscode.workspace.getConfiguration("workbench").get("colorTheme");
}

async function setColorTheme(label) {
    if (colorTheme() === label) return;
    if (!vscode.window.state.focused) {
        await new Promise(r => setTimeout(r, 40 + (process.pid % 8) * 40));
        if (colorTheme() === label) return;
    }
    await vscode.workspace.getConfiguration("workbench")
        .update("colorTheme", label, vscode.ConfigurationTarget.Global);
}

function activate(context) {
    const ownThemes = (context.extension.packageJSON.contributes || {}).themes || [];
    const customFile = path.join(context.extensionPath, "themes", "custom.json");
    let customLoaded = colorTheme() === CUSTOM ? readText(customFile) : null;
    let prompted = null;
    let lastId = null;

    function bundled(id) {
        const entry = ownThemes.find(t => t.label !== CUSTOM && t.path === "./themes/" + id + ".json");
        if (!entry) return null;
        return validTheme(path.join(context.extensionPath, entry.path)) ? entry.label : null;
    }

    async function sync(force, regenerate) {
        if (!config().get("enabled", true)) return;
        const dir = shellDir();
        const settings = readJson(path.join(dir, "theme.json"));
        if (!settings || !settings.theme) return;
        if (settings.vscodeThemeSync === false) { lastId = null; return; }
        if (settings.theme === lastId && !force) return;
        lastId = settings.theme;

        let label = regenerate ? null : bundled(settings.theme);
        if (label) return setColorTheme(label);

        const shellTheme = readJson(path.join(dir, "themes", settings.theme + ".json"));
        if (!generator.usable(shellTheme)) {
            if (regenerate) vscode.window.showWarningMessage(
                `Quickshell: the colors of theme "${settings.theme}" are incomplete, nothing generated.`);
            return;
        }
        const text = JSON.stringify(generator.build(shellTheme, CUSTOM), null, 2) + "\n";
        if (readText(customFile) !== text) fs.writeFileSync(customFile, text);
        await setColorTheme(CUSTOM);
        if (customLoaded === null) customLoaded = text;
        if (customLoaded !== text && prompted !== text) {
            prompted = text;
            const choice = await vscode.window.showInformationMessage(
                `Quickshell: VS Code theme generated for "${shellTheme.name || settings.theme}". Reload the window to see it.`,
                "Reload");
            if (choice === "Reload") vscode.commands.executeCommand("workbench.action.reloadWindow");
        }
    }

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
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e => {
        if (!e.affectsConfiguration("quickshellThemeSync")) return;
        if (e.affectsConfiguration("quickshellThemeSync.shellDir")) watch();
        later(true);
    }));
    context.subscriptions.push(vscode.commands.registerCommand(
        "quickshellThemeSync.syncNow", () => sync(true)));
    context.subscriptions.push(vscode.commands.registerCommand(
        "quickshellThemeSync.regenerate", () => sync(true, true)));

    later(true, 0);
}

function deactivate() {}

module.exports = { activate, deactivate };
