# American Conquest Gold Edition: Linux compatibility

MIT-licensed launch scripts, rendering settings, and a reproducible AI crash
patch for **American Conquest Gold Edition** on Linux, by Şeref Çimen.

This is a community compatibility project, **not a native Linux port or a game
distribution**. You must supply your own legally obtained game installation.
No game executable, assets, saves, third-party DLLs, or Wine prefix is included.

## Respect to the mod creators

**Gold Edition and Rise of East Asia are the work of the
[American Conquest China team](https://www.americanconquest.info/), not this
Linux compatibility project.** Thank you for creating and sharing the mod.

Their [Gold Edition page and original credits](https://www.americanconquest.info/gold.html)
credit:

- **shiunghanching** — project lead, mod content, mission design, and text.
- **LIN** — AI programming.
- **Adore zhuo** and **Mr.吳** — mission design, alongside shiunghanching.
- **Mr.吳, Adore zhuo, 呕买浪, 土著女爵, and naochu** — testing.
- **A.Soldier** — text, alongside shiunghanching.
- The additional contributors and special thanks listed on their original page.

Please visit their site and consider
[supporting the creators and website](https://www.americanconquest.info/contact.html#donate).
This repository contributes only Linux compatibility work; it does not claim
authorship of the mod or permission to relicense its content.

### 致模组制作团队的感谢信

尊敬的 shiunghanching 及征服美洲中文站、《黄金版》《东亚崛起》制作团队的各位成员：

你们好！

作为一名在 Linux 上游玩《征服美洲：黄金版》的玩家，我想向你们致以诚挚的感谢。
感谢你们为这款游戏投入的时间、心血与创造力，也感谢参与内容制作、AI 编程、
战役设计、测试和文本工作的每一位成员。你们带来的新势力、新战役与丰富内容，
让玩家能够继续探索和享受这款经典游戏。

这个小项目只是我为 Linux 游玩环境整理的兼容脚本、配置与针对已知崩溃的补丁工具，
并不是游戏或模组的官方移植，也不代表贵团队。模组的创作功劳属于你们；
本仓库的 MIT 许可仅适用于这里的兼容工具及相关文档，不适用于游戏或模组内容，
也不授予任何使用、修改或再分发你们素材的额外权利。

谢谢你们的付出与分享，也谢谢你们维护网站、凝聚玩家社区。
希望这份小小的兼容工作，能让更多使用 Linux 的玩家有机会欣赏你们的成果。
在此向全体制作人员与贡献者致敬，祝大家生活顺遂，创作愉快！

一位心怀感谢的玩家  
Şeref Çimen

#### A letter to the team (English)

Dear shiunghanching and all members of the American Conquest China,
Gold Edition, and Rise of East Asia teams,

Thank you for all the time and care you have devoted to the American Conquest
community, and for your work on the game, tools, and resources.

I’m a Linux user, and I’ve recently been working on getting the game package
available on your website running on Linux. I would be grateful for the
opportunity to share my setup with you, and would greatly appreciate any
feedback you might have. I hope this work could also be useful to other
Linux players.

Project link: [American Conquest Linux compatibility](https://github.com/seros-cimenstein/american-conquest-linux-compat)

This is an unofficial compatibility project, not a native Linux port or a
distribution of the game or mod. All credit for the mod belongs to your team.

I hope you don’t mind me reaching out. Would this be an appropriate place to
share it, or is there someone else I should contact?

Thank you for your time, and best wishes!

A grateful player,  
Şeref Çimen

## What this fixes

- Black-screen/rendering problems: Proton's 1920×1080 virtual desktop with
  [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw), OpenGL, and `minfps=-2`.
- Conflicting wrappers: moves the bundled CossacksGL `dplayx.dll` aside and
  selects Wine's built-in DirectPlay implementation.
- Bad display state: rewrites `mode.dat` at launch; removes stale `DDraw.log`
  and `lock.report`, and archives previous crash logs/dumps outside the game.
- Observed late-match AI crashes: an unsigned index comparison and three
  readable-address guards, reproduced locally without distributing `dmcr.exe`.
- Severe CPU-0 performance loss: `singlecpu=false` with the full guard suite,
  plus 60 FPS/game-tick limits.

These are targeted mitigations, not a guarantee of crash-free gameplay or a
repair of the engine's underlying memory corruption. Readability checks cannot
validate object lifetime or eliminate races.

## Requirements

- Linux with Bash, Perl (core `Digest::SHA`), Python 3, Git, curl, unzip, and
  GNU coreutils. No compiler or root installation is needed.
- Steam and Proton Experimental installed through Steam. Proton 9.0 (Beta) is
  the historical fallback. The default Steam location is
  `$HOME/.local/share/Steam`; see overrides below for another library.
- A writable, extracted Gold Edition game directory containing `dmcr.exe`.
  **Other releases/builds are not supported by the binary patch.** A checksum
  mismatch is intentional protection; do not bypass it.
- [cnc-ddraw v7.1.0.0](https://github.com/FunkyFr3sh/cnc-ddraw/releases/tag/v7.1.0.0),
  downloaded separately by the installation commands.

## Install

**Exit the game first.** These commands patch your executable, replace the
DirectDraw wrapper/configuration and launchers, and retain backups. They do not
install or download the proprietary game.

Clone this project, then run the following in Bash. Change `GAME` to your own
installation path. Keep the entire block together so errors stop installation.

```bash
git clone https://github.com/seros-cimenstein/american-conquest-linux-compat.git
cd american-conquest-linux-compat
```

```bash
(
set -eu
GAME="$HOME/Games/American Conquest Gold Edition"
test -f "$GAME/dmcr.exe"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

curl --fail --location \
  https://github.com/FunkyFr3sh/cnc-ddraw/releases/download/v7.1.0.0/cnc-ddraw.zip \
  --output "$WORK/cnc-ddraw.zip"
printf '%s  %s\n' \
  0b13ab89a64c9918189b1dadd449ef6ed3cb3b7b19cabd96d8adbd95505bb908 \
  "$WORK/cnc-ddraw.zip" | sha256sum --check -
unzip -q "$WORK/cnc-ddraw.zip" -d "$WORK/cnc-ddraw"

# Keep all upstream defaults and apply only this project's settings.
python3 - "$WORK/cnc-ddraw/ddraw.ini" config/ddraw.ini "$WORK/ddraw.ini" <<'PY'
import configparser
import sys
config = configparser.ConfigParser(interpolation=None, strict=False)
with open(sys.argv[1], encoding="utf-8-sig") as source:
    config.read_file(source)
with open(sys.argv[2], encoding="utf-8") as overrides:
    config.read_file(overrides)
with open(sys.argv[3], "w", encoding="utf-8") as target:
    config.write(target)
PY

perl tools/patch-ac-ai-pointer-suite.pl "$GAME/dmcr.exe"
BACKUP="$(mktemp -d "$GAME/linux-compat-backup.XXXXXX")"
for file in ddraw.dll ddraw.ini run-linux.sh run-linux-desktop.sh; do
  if [ -e "$GAME/$file" ]; then
    cp -p -- "$GAME/$file" "$BACKUP/"
  fi
done
cp -- "$WORK/cnc-ddraw/ddraw.dll" "$GAME/ddraw.dll"
cp -- "$WORK/ddraw.ini" "$GAME/ddraw.ini"
cp -- run-linux.sh run-linux-desktop.sh "$GAME/"
chmod +x "$GAME/run-linux.sh" "$GAME/run-linux-desktop.sh"
printf 'Installed. Configuration/launcher backups: %s\n' "$BACKUP"
)
```

The patcher verifies the full input and output SHA-256 **before writing**.
It accepts the original executable and this project's two earlier patch states.
It creates `dmcr.exe.ac-linux.bak`, refuses to replace an existing backup,
and does nothing if the final patch is already installed.

Launch from the **game directory**, not the cloned compatibility repository:

```bash
cd "$HOME/Games/American Conquest Gold Edition"
./run-linux.sh
```

The nearest-neighbor mode needs no external shader package. Do not restore the
bundled `dplayx.dll` while using this configuration. Its original bytes are
preserved as `dplayx.dll.cossacksgl-disabled` (with a timestamp if needed).

## Configuration

Environment overrides for `run-linux.sh`:

| Variable | Default / purpose |
| --- | --- |
| `STEAM_ROOT` | `$HOME/.local/share/Steam`; Steam client installation |
| `PROTON` | `$STEAM_ROOT/steamapps/common/Proton - Experimental/proton`; full path to an executable Proton launcher, including one in another library |
| `AC_GOLD_PREFIX` | `${XDG_DATA_HOME:-$HOME/.local/share}/american-conquest-gold/prefix`; Proton compatibility-data root, containing `pfx/` |
| `AC_GOLD_LOG_DIR` | `${XDG_STATE_HOME:-$HOME/.local/state}/american-conquest-gold`; archived crash logs/dumps |
| `AC_GOLD_DESKTOP_SIZE` | `1920x1080`; Wine desktop and `mode.dat` dimensions |

For a different resolution, also change `width`/`height` under both `[ddraw]`
and `[DMCR]` in the installed `ddraw.ini` to match the desktop override.
Only 1920×1080 is covered by the recorded gameplay checks. Steam/Proton must
have access to the game directory; sandboxed Steam installations may need
additional filesystem permissions.

## Engine patch details

The supported executable uses image base `0x400000`.

| Change | File offset / virtual address | Behavior |
| --- | --- | --- |
| Unsigned index bound | `0x86F3F` / `0x00487B3F` | `JLE` → `JBE`; rejects negative/high-bit array indices |
| Primary AI object | `0x8BD7E` / `0x0048C97E` | Checks the six-byte header before dereferencing |
| Main AI table | `0x8BDB7` / `0x0048C9B7` | Checks the exact indexed dword |
| Optional byte table | `0x8BDE7` / `0x0048C9E7` | Checks the exact indexed byte; skips adjustment if unreadable |

The guards call the executable's existing readability helper at `0x0063ADF9`.
Invalid mandatory data follows the routine's existing return at `0x0048C973`;
invalid optional data skips to `0x0048C9F6`. Guard code occupies the backed
executable tail starting at file offset `0x26E370` / VA `0x0066EF70`.
The first section's raw size is extended to `0x26E000` without changing the
file length. The historical null-guard instruction tail is retained so the
result exactly matches the installed, gameplay-checked executable.

SHA-256 reference values:

| File/state | SHA-256 |
| --- | --- |
| Original Gold Edition `dmcr.exe` | `54a63ca5a9dd8a8d63beb708a4ae82e12b73ac18b5b49155d881802e09877fd4` |
| Final patched `dmcr.exe` | `6b12d1c94b22093ea345a0cecf3df31f517ecdfdafeb607a396d12757f3a141f` |
| cnc-ddraw v7.1.0.0 `ddraw.dll` | `85e0f7d530dfda134793a57cb3e76b0287dcc96892ee57162dd68f47283b03a9` |

## Verification and limitations

The original setup's recovery notes record successful menu, random-map and
live-gameplay checks at 1920×1080. After the full guard suite, a replay of the
USA/Japan poisoned-pointer save ran for more than five minutes on CPUs 0–7,
advanced from game time `00:11:01` to approximately `01:38:20`, and wrote
several autosaves without another crash. Earlier short replays did **not**
establish general stability; they were followed by additional engine crashes.
Those private saves and screenshots are not redistributed here.

For publication, the portable patcher was exercised on copies of the original,
null-guard-only, and two-patch executables. Each produced the exact final
checksum above. Already-patched inputs were left unchanged; unknown builds
and existing-backup collisions were refused without modifying the input.
The downloaded upstream DirectDraw DLL matches the installed DLL byte-for-byte.
This does not establish compatibility with every system or game build.

## Rollback

Exit the game. Restore your executable from `dmcr.exe.ac-linux.bak` and restore
the wrapper/configuration/launchers from the printed `linux-compat-backup.*`
directory. Files that did not exist before installation have no backup: remove
those newly installed files if returning completely to the old setup. If you
are abandoning cnc-ddraw, restore the original `dplayx.dll` from the disabled
copy as well. Do not delete saves or the Proton prefix as part of rollback.

## License and credits

The compatibility scripts, project settings, and documentation in this
repository are licensed under [MIT](LICENSE). This does **not** relicense
American Conquest, Gold Edition modifications, game assets, or patched copies
of their binaries; their respective rights holders retain their rights.

[cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) and
[Proton](https://github.com/ValveSoftware/Proton) are separate third-party
projects under their own licenses. Their binaries and sources are not bundled.
No affiliation with or endorsement by the game's rights holders is implied.
