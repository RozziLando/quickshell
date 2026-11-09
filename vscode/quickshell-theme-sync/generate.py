#!/usr/bin/env python3
"""VS Code color theme from a Quickshell palette (themes/<id>.json).

For shell themes that have no official VS Code theme (e.g. midnight):

    python3 generate.py midnight

writes themes/<id>.json in this extension. Then add it to "contributes.themes"
in package.json (label "<Name> (Quickshell)") and put the same label in the
shell theme file: "vscode": { "theme": "<Name> (Quickshell)", "extension": "" }.

Interface colors come from the shell palette (same look as the island), the
terminal from the theme's 16 ANSI colors, syntax colors from the ANSI ones.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.normpath(os.path.join(HERE, "..", ".."))


def alpha(color, a):
    """#rrggbb + transparency (0..1) -> #rrggbbaa"""
    return color[:7] + "%02x" % round(a * 255)


def build(t):
    c, term = t["colors"], t["terminal"]
    a = term["ansi"]
    red, green, yellow, blue, magenta, cyan = a[1], a[2], a[3], a[4], a[5], a[6]
    orange = a[9] if a[9].lower() != red.lower() else yellow
    bg, card, surface, border = c["background"], c["card"], c["surface"], c["border"]
    text, muted, accent = c["text"], c["textMuted"], c["accent"]

    colors = {
        "foreground": c["textSecondary"],
        "focusBorder": accent,
        "selection.background": alpha(accent, 0.35),
        "widget.shadow": "#00000066",
        "errorForeground": c["warning"],
        "textLink.foreground": accent,
        "textLink.activeForeground": accent,
        "icon.foreground": c["textSecondary"],
        "button.background": accent,
        "button.foreground": bg,
        "button.hoverBackground": alpha(accent, 0.85),
        "button.secondaryBackground": surface,
        "button.secondaryForeground": text,
        "badge.background": accent,
        "badge.foreground": bg,
        "progressBar.background": accent,
        "input.background": surface,
        "input.border": border,
        "input.foreground": text,
        "input.placeholderForeground": muted,
        "inputOption.activeBorder": accent,
        "dropdown.background": surface,
        "dropdown.border": border,
        "dropdown.foreground": text,
        "checkbox.background": surface,
        "checkbox.border": border,
        "scrollbarSlider.background": alpha(c["highlight"], 0.6),
        "scrollbarSlider.hoverBackground": c["highlight"],
        "scrollbarSlider.activeBackground": c["selection"],
        "titleBar.activeBackground": bg,
        "titleBar.activeForeground": text,
        "titleBar.inactiveBackground": bg,
        "titleBar.inactiveForeground": muted,
        "titleBar.border": border,
        "activityBar.background": bg,
        "activityBar.foreground": text,
        "activityBar.inactiveForeground": muted,
        "activityBar.border": border,
        "activityBar.activeBorder": accent,
        "activityBarBadge.background": accent,
        "activityBarBadge.foreground": bg,
        "sideBar.background": bg,
        "sideBar.foreground": c["textSecondary"],
        "sideBar.border": border,
        "sideBarTitle.foreground": text,
        "sideBarSectionHeader.background": bg,
        "sideBarSectionHeader.foreground": text,
        "sideBarSectionHeader.border": border,
        "list.activeSelectionBackground": c["highlight"],
        "list.activeSelectionForeground": text,
        "list.inactiveSelectionBackground": surface,
        "list.inactiveSelectionForeground": text,
        "list.hoverBackground": alpha(c["highlight"], 0.6),
        "list.focusOutline": accent,
        "list.highlightForeground": accent,
        "list.errorForeground": c["warning"],
        "list.warningForeground": yellow,
        "editorGroupHeader.tabsBackground": bg,
        "editorGroupHeader.tabsBorder": border,
        "editorGroup.border": border,
        "tab.activeBackground": card,
        "tab.activeForeground": text,
        "tab.activeBorderTop": accent,
        "tab.inactiveBackground": bg,
        "tab.inactiveForeground": muted,
        "tab.border": border,
        "tab.hoverBackground": surface,
        "breadcrumb.foreground": muted,
        "breadcrumb.focusForeground": text,
        "editor.background": card,
        "editor.foreground": text,
        "editorCursor.foreground": term["cursor"],
        "editor.lineHighlightBackground": alpha(surface, 0.6),
        "editor.lineHighlightBorder": "#00000000",
        "editor.selectionBackground": c["selection"],
        "editor.inactiveSelectionBackground": alpha(c["selection"], 0.6),
        "editor.selectionHighlightBackground": alpha(accent, 0.18),
        "editor.wordHighlightBackground": alpha(accent, 0.18),
        "editor.findMatchBackground": alpha(yellow, 0.45),
        "editor.findMatchHighlightBackground": alpha(yellow, 0.22),
        "editorLineNumber.foreground": c["textDisabled"],
        "editorLineNumber.activeForeground": c["textSecondary"],
        "editorIndentGuide.background1": alpha(border, 0.9),
        "editorIndentGuide.activeBackground1": c["highlight"],
        "editorWhitespace.foreground": c["textDisabled"],
        "editorBracketMatch.background": alpha(accent, 0.2),
        "editorBracketMatch.border": alpha(accent, 0.6),
        "editorError.foreground": red,
        "editorWarning.foreground": yellow,
        "editorInfo.foreground": blue,
        "editorGutter.addedBackground": green,
        "editorGutter.modifiedBackground": blue,
        "editorGutter.deletedBackground": red,
        "editorWidget.background": surface,
        "editorWidget.border": border,
        "editorSuggestWidget.background": surface,
        "editorSuggestWidget.border": border,
        "editorSuggestWidget.selectedBackground": c["highlight"],
        "editorHoverWidget.background": surface,
        "editorHoverWidget.border": border,
        "peekView.border": accent,
        "panel.background": bg,
        "panel.border": border,
        "panelTitle.activeBorder": accent,
        "panelTitle.activeForeground": text,
        "panelTitle.inactiveForeground": muted,
        "statusBar.background": bg,
        "statusBar.foreground": c["textSecondary"],
        "statusBar.border": border,
        "statusBar.noFolderBackground": bg,
        "statusBar.debuggingBackground": accent,
        "statusBar.debuggingForeground": bg,
        "statusBarItem.remoteBackground": accent,
        "statusBarItem.remoteForeground": bg,
        "quickInput.background": surface,
        "quickInputList.focusBackground": c["highlight"],
        "menu.background": surface,
        "menu.foreground": text,
        "menu.selectionBackground": c["highlight"],
        "menu.border": border,
        "notifications.background": surface,
        "notifications.border": border,
        "gitDecoration.addedResourceForeground": green,
        "gitDecoration.modifiedResourceForeground": yellow,
        "gitDecoration.deletedResourceForeground": red,
        "gitDecoration.untrackedResourceForeground": cyan,
        "gitDecoration.ignoredResourceForeground": muted,
        "terminal.background": term["background"],
        "terminal.foreground": term["foreground"],
        "terminalCursor.foreground": term["cursor"],
        "terminal.selectionBackground": term["selectionBackground"],
    }
    names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
    for i, n in enumerate(names):
        colors["terminal.ansi" + n] = a[i]
        colors["terminal.ansiBright" + n] = a[i + 8]

    def tok(scope, fg, style=None):
        s = {"foreground": fg}
        if style:
            s["fontStyle"] = style
        return {"scope": scope, "settings": s}

    tokens = [
        tok(["comment", "punctuation.definition.comment"], muted, "italic"),
        tok(["keyword", "storage.type", "storage.modifier", "keyword.operator.new",
             "keyword.operator.expression", "keyword.control"], magenta),
        tok(["keyword.operator", "punctuation"], c["textSecondary"]),
        tok(["string", "punctuation.definition.string"], green),
        tok(["constant.character.escape", "string.regexp"], cyan),
        tok(["constant.numeric", "constant.language", "constant.other"], orange),
        tok(["entity.name.function", "support.function", "meta.function-call"], blue),
        tok(["entity.name.type", "entity.name.class", "support.type", "support.class",
             "entity.other.inherited-class"], yellow),
        tok(["variable", "meta.definition.variable"], text),
        tok(["variable.parameter"], c["textSoft"], "italic"),
        tok(["variable.language", "variable.other.constant"], red),
        tok(["entity.name.tag"], red),
        tok(["entity.other.attribute-name", "variable.other.property",
             "variable.other.object.property", "support.type.property-name"], cyan),
        tok(["entity.name.namespace", "entity.name.module"], yellow),
        tok(["markup.heading", "entity.name.section"], blue, "bold"),
        tok(["markup.bold"], text, "bold"),
        tok(["markup.italic"], text, "italic"),
        tok(["markup.inline.raw", "markup.fenced_code"], green),
        tok(["markup.underline.link", "string.other.link"], accent),
        tok(["markup.inserted"], green),
        tok(["markup.deleted"], red),
        tok(["invalid"], c["warning"]),
    ]
    return {
        "name": t.get("name", "") + " (Quickshell)",
        "type": "dark",
        "semanticHighlighting": True,
        "colors": colors,
        "tokenColors": tokens,
    }


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: generate.py <shell theme id>")
    tid = sys.argv[1]
    src = os.path.join(SHELL, "themes", tid + ".json")
    with open(src) as f:
        theme = build(json.load(f))
    out = os.path.join(HERE, "themes", tid + ".json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump(theme, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print("written", out, "-", theme["name"])


if __name__ == "__main__":
    main()
