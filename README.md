# Quickshell island

A Hyprland shell built on Quickshell (>= 0.3): an island at the top of the
screen with clock, notifications, launcher, media player, control center,
lock screen and login screen. Works on **Arch** and **Fedora**.

## Screenshots

<table>
  <tr>
    <td><img src="screenshots/island.png" alt="Island" width="600"></td>
    <td><img src="screenshots/control_center.png" alt="Control center" width="600"></td>
    <td><img src="screenshots/app_launcher.png" alt="App launcher" width="600"></td>
    <td><img src="screenshots/theme_switcher.png" alt="Theme and wallpaper switcher" width="600"></td>
    <td><img src="screenshots/media_player.png" alt="Media player" width="600"></td>
    <td><img src="screenshots/performance_monitoring.png" alt="Performance monitoring" width="600"></td>
  </tr>
  <tr>
    <td align="center"><b>Island</b></td>
    <td align="center"><b>Control center</b></td>
    <td align="center"><b>App launcher</b></td>
    <td align="center"><b>Theme and wallpaper switcher</b></td>
    <td align="center"><b>Media player</b></td>
    <td align="center"><b>Performance monitoring</b></td>
  </tr>
</table>

## Installation

```sh
[ -d ~/.config/quickshell ] && mv ~/.config/quickshell ~/.config/quickshell_backup
git clone https://github.com/RozziLando/quickshell.git ~/.config/quickshell
cd ~/.config/quickshell
chmod +x install.sh
./install.sh
```

Run it as your normal user: it asks for the sudo password when needed.
`install.sh` does only two things:

1. detects Arch or Fedora and installs the [dependencies](#dependencies).
   Packages that are already installed are skipped (`pacman --needed` on
   Arch; on Fedora it also enables the Hyprland and Quickshell COPRs);
2. if VS Code is installed, asks whether to install the extensions that make
   VS Code follow the shell theme (see [VS Code themes](#vs-code-themes)).

Everything else is up to you: put (or link) the folder in
`~/.config/quickshell`, set your options in [`theme.json`](#themejson), add
the [keybinds](#keybinds) you want to the Hyprland config and start the shell
with Hyprland (`exec-once = quickshell`, or `hl.exec_cmd("quickshell")` in a
Lua config). For the login screen run `sudo greeter/install.sh`.

**Profile picture.** To show your photo on the lock screen and the login
screen, put it in `assets/` named `avatar.png`, `avatar.jpg` or
`avatar.jpeg` (a square image looks best). Without it the circle shows the
first letter of your user name. The file is ignored by git, so copy it by
hand on each PC.

| Option | Effect |
|---|---|
| `./install.sh -y` | accept the defaults, ask nothing |
| `./install.sh --no-packages` | skip the package installation |

## Dependencies

| Used for | Arch | Fedora |
|---|---|---|
| Shell (>= 0.3) | `quickshell` | `quickshell` (COPR `errornointernet/quickshell`) |
| Compositor | `hyprland` | `hyprland` (COPR `solopasha/hyprland`) |
| Wallpaper | `awww` | `swaybg` |
| Wi-Fi | `networkmanager` | `NetworkManager` |
| Bluetooth | `bluez` `bluez-utils` | `bluez` |
| Audio | `pipewire` `pipewire-pulse` `wireplumber` `libpulse` | `pipewire` `pipewire-pulseaudio` `wireplumber` `pulseaudio-utils` |
| Brightness, battery | `brightnessctl` `upower` | `brightnessctl` `upower` |
| Media keys | `playerctl` | `playerctl` |
| Screenshots, lock screen | `grim` `slurp` `wl-clipboard` | `grim` `slurp` `wl-clipboard` |
| Notifications, logind signals | `libnotify` `glib2` | `libnotify` `glib2` |
| Login screen copy | `diffutils` | `diffutils` |
| .webp wallpapers | `qt6-imageformats` | `qt6-qtimageformats` |
| Fonts | `inter-font` `noto-fonts-emoji` `noto-fonts-cjk` | `rsms-inter-fonts` `google-noto-color-emoji-fonts` `google-noto-sans-cjk-fonts` |
| Login screen (optional) | `greetd` `cage` | `greetd` `cage` |

`install.sh` installs all of them. The icon font (Phosphor) ships with the
shell in `assets/fonts/`.

## IPC

`qs ipc call <target> <function>` controls the running shell from a
terminal, a script or a keybind. `qs ipc show` lists everything available.

| Command | What it does |
|---|---|
| `qs ipc call launcher toggle` | open / close the app launcher |
| `qs ipc call controlcenter toggle` | open / close the control center |
| `qs ipc call power toggle` | open / close the power menu |
| `qs ipc call screenshot region` | screenshot of an area selected with the mouse, to the clipboard |
| `qs ipc call screenshot screen` | screenshot of the screen under the mouse, to the clipboard |
| `qs ipc call screenshot save` | screenshot of the screen under the mouse, to the clipboard and saved in `~/Pictures` |
| `qs ipc call media peek` | show the media player for a few seconds |
| `qs ipc call theme list` | list the themes |
| `qs ipc call theme current` | print the active theme |
| `qs ipc call theme set <id>` | apply a theme (shell, kitty, Nautilus, wallpaper), e.g. `theme set nord` |
| `qs ipc call lock lock` | lock the screen (with `"lockScreen": true`) |
| `qs ipc call lock suspend` | lock and suspend |

## Keybinds

Suggested binds for the Hyprland config (add them yourself):

| Keys | Command |
|---|---|
| `ALT + SPACE` | `qs ipc call launcher toggle` |
| `SUPER + C` | `qs ipc call controlcenter toggle` |
| `SUPER + ESCAPE` | `qs ipc call power toggle` |
| `SUPER + S` | `qs ipc call screenshot region` |
| `SUPER + A` | `qs ipc call screenshot save` |
| `SUPER + Q` | `pkill -x quickshell \|\| quickshell` (restart the shell) |
| Play / Pause / Next / Previous | `playerctl …; qs ipc call media peek` |
| Volume up / down / mute, mic mute | `wpctl …` (the island shows the volume bar by itself) |
| Screen brightness (laptops) | `brightnessctl …` (the island shows the bar by itself) |
| Keyboard backlight (if present) | `brightnessctl -d <device> …` |

Other useful commands:

| Command | What it does |
|---|---|
| `qs` / `quickshell -d` | start the shell (`-d`: detached from the terminal) |
| `pkill -x quickshell` | stop the shell |
| `qs log` | log of the running shell (`qs log -f` follows it) |
| `qs list` | running instances (there should be one) |

Saved `.qml` files and `theme.json` are reloaded automatically: there is no
need to restart the shell.

## VS Code themes

Optional: when the shell theme changes, VS Code switches to the matching
color theme, live. `install.sh` asks for it; later you can run
`scripts/vscode.sh` (also to update it). It installs:

- the VS Code theme of every shell theme, from the marketplace. Each
  `themes/<id>.json` says which one:
  `"vscode": { "theme": "Dracula Theme", "extension": "dracula-theme.theme-dracula" }`
  (`theme` is the exact name shown in VS Code);
- `vscode/quickshell-theme-sync`: the extension that follows the shell
  (it watches `theme.json`), plus the themes made for the shell
  (Midnight). It acts only when the shell theme changes, so a theme picked
  by hand in VS Code stays until the next one. `"vscodeThemeSync": false`
  in `theme.json` turns it off;
- `vscode/xcode`: Xcode Dark, which is not on the marketplace.

**Installing by hand.** Each local extension folder also holds its ready
package, rebuilt by every run of the script (`scripts/vscode.sh --pack`
only rebuilds them):

- `vscode/quickshell-theme-sync/local.quickshell-theme-sync-<version>.vsix`
- `vscode/xcode/local.xcode-<version>.vsix`

If the script does not work, install them with
`code --install-extension <file>.vsix`, or in VS Code: Extensions view →
`…` menu → *Install from VSIX…*. The marketplace themes can be installed
from the Extensions view, searching the `extension` id of each theme file.
Then reload VS Code.

For a new shell theme without an official VS Code theme:
`python3 vscode/quickshell-theme-sync/generate.py <id>`, then add the theme
to that extension's `package.json` and to the `vscode` field of the shell
theme, and run `scripts/vscode.sh`.

## theme.json

All the settings live in `theme.json`, in this folder. Changes apply as soon
as the file is saved.

| Option | Values | Meaning |
|---|---|---|
| `scale` | number (0.5–3) | size of the whole shell |
| `monitor` | `""` or a name like `"HDMI-A-1"`, `"DP-1"`, `"eDP-1"` | screen of the island (`hyprctl monitors`). Empty or not connected: the laptop screen, otherwise the first one |
| `fontFamily` | font name | shell font |
| `iconFont` | `phosphor`, `phosphor-light`, `phosphor-bold`, `phosphor-fill`, `classic` | icon style |
| `islandStyle` | `"floating"` / `"attached"` | detached island with side circles, or attached to the top edge |
| `minimal` | `true` / `false` | only the clock at rest, icons appear on hover |
| `autoHide` | `true` / `false` | hide the island when windows are open (hover the top edge to bring it back) |
| `glowEnabled` | `true` / `false` | glow in the theme color around island and windows |
| `darkShadow` | `true` / `false` | classic dark shadow instead of the glow |
| `glass` | `true` / `false` | translucent island and windows with blurred background |
| `glassOpacity` | 0.3–1 | opacity with `glass` |
| `lockBlur` | `true` / `false` | lock screen: blurred screen contents, or the plain wallpaper |
| `loginBlur` | `true` / `false` | login screen: blurred or plain wallpaper |
| `lockScreen` | `true` / `false` | lock screen (shortcut, inactivity, before sleep) |
| `loginScreen` | `true` / `false` | `false`: automatic login into Hyprland (applied by `sudo greeter/install.sh`) |
| `sleepEnabled` | `true` / `false` | sleep from the power menu and after inactivity |
| `idleLockMinutes` | minutes, `0` = never | lock after this much inactivity |
| `idleSleepMinutes` | minutes, `0` = never | sleep after this much inactivity |
| `bluetoothOnStartup` | `true` / `false` | Bluetooth on or off at the first shell start after boot |
| `theme` | theme id | `catppuccin-mocha`, `dracula`, `everforest`, `gruvbox`, `iceberg`, `kanagawa`, `midnight`, `night-owl`, `nord`, `one-dark`, `rose-pine`, `solarized`, `sonokai`, `tokyo-night`, `xcode` (files in `themes/`) |
| `wallpaperDir` | folder | wallpapers shown in the launcher (`Tab` switches to themes and wallpapers) |
| `wallpaperTransition` | `grow`, `outer`, `wave`, `wipe`, `fade`, `left`, `right`, `top`, `bottom`, `random`, `simple` | wallpaper change animation (awww) |
| `vscodeThemeSync` | `true` / `false` | VS Code follows the shell theme (needs the [VS Code extensions](#vs-code-themes)); `false`: VS Code keeps its own theme |
