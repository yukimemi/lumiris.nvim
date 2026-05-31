# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## コンセプト

- **denops 廃止・pure Lua / Neovim 専用**: [`lumiris.vim`](https://github.com/yukimemi/lumiris.vim) (denops/Deno) の後継。RPC オーバーヘッドなしの in-process Lua。インストール済み colorscheme を timer / event で自動ローテーションし、like/hate の嗜好を JSON 永続化する。
- **設定はテーブル一本**: `g:lumiris_*` グローバルは全廃。`require("lumiris").setup({...})` のみ。`lua/lumiris/config.lua` に `M.defaults` + `vim.tbl_deep_extend` + LuaCATS `---@class lumiris.Options`。
- **Convention over Configuration**: `plugin/lumiris.lua` が `:Lumiris*` コマンドを eager 登録するので `setup()` 無しでもコマンドは効く。`setup()` は自動ローテーション (timer + autocmd) のためだけ。
- **静的設定と実行時/永続状態の分離**: `setup()` の値は static config。`enabled` フラグは `state.lua` のメモリ、like/hate 嗜好は `stdpath("state")/lumiris/prefs.json` (`vim.json`)。denops 版の TOML は廃止。
- **Notify ゲート契約**: background のログ (`timer` / `autocmd` / apply 失敗) は全て `lua/lumiris/log.lua` の `M.at/info/warn/...` 経由。`notify = false` で真に黙る。`log_level` が severity の閾値。ユーザが叩いた `:Lumiris*` の即時フィードバックだけ `log.echo` で notify トグルに関係なく常に出す (ユーザが要求したものだから)。

## Git ワークフロー

- **main に直接 push しない。** 必ずフィーチャーブランチ + Pull Request。
- ブランチ名は変更内容を端的に (例: `add-weighted-pick`, `fix-windows-state-path`)。
- **PR タイトル・本文・コミットメッセージは英語。** Conventional Commits (`feat:` / `fix:` / `refactor:` / `test:` / `chore:`)。
- 全 PR で **Gemini Code Assist** と **CodeRabbit** がレビューする。両 bot の指摘に対処 (fix を push → 対応 thread に `@gemini-code-assist` / `@coderabbitai` 付きで reply) し、actionable が出なくなる + オーナー (@yukimemi) の明示承認まで merge しない。bot-authored PR (Renovate 等) はこの gate を適用しない。

## Development Commands

テストは **mini.test** (plenary.nvim は 2026-06-30 アーカイブのため不採用)。`scripts/run_tests.lua` が headless ランナーで、失敗時は `cquit` で非 0 終了する。

```bash
# mini.nvim をローカルに用意 (CI は deps/mini.nvim に clone)
git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim

# 全 spec (CI と同じ per-file ループ。Windows でも Bash で共通)
set -e
status=0
for f in tests/lumiris/test_*.lua; do
  echo "=== $f ==="
  nvim -u NONE -l scripts/run_tests.lua "$f" || status=$?
done
exit $status

# 単一 spec
nvim -u NONE -l scripts/run_tests.lua tests/lumiris/test_state.lua

# 対話的に回す (mini.test を rtp に乗せて起動 → :lua MiniTest.run())
nvim --noplugin -u scripts/minitest_init.lua
```

- `nvim -u NONE -l` で user config を読まずにスクリプト実行 (plenary であった「子 nvim が user init.lua を読む」罠を構造的に回避)。rtp は `run_tests.lua` 内で cwd と `deps/mini.nvim` を手動で prepend する。
- mini.nvim は `$MINI_NVIM` / `deps/mini.nvim` / `stdpath("data")/lazy/mini.nvim` の順で解決。
- spec ファイル名は mini.test 既定の **`test_*.lua`** (plenary の `*_spec.lua` ではない)。

## アーキテクチャ

### ファイル構成

```text
plugin/lumiris.lua        — :Lumiris* を eager 登録 (setup 不要で効く)
lua/lumiris/
  init.lua                — setup() + 便利 Lua API (change/like/hate/enable/disable/candidates)
  config.lua              — defaults + tbl_deep_extend、LuaCATS ---@class lumiris.Options
  log.lua                 — notify ゲート (at/info/warn/...) + ユーザ向け echo
  state.lua               — enabled フラグ (memory) + like/hate prefs の JSON 永続 (load/save/like/hate/weight/is_hated)
  colorscheme.lua         — candidates() フィルタ / pick() 重み付き選択 / apply() / rotate() interval ゲート
  autocmd.lua             — augroup + events autocmd + vim.uv timer (register/unregister、setup で冪等)
  command.lua             — :Lumiris{Change,Like,Hate,Enable,Disable,Toggle}
  health.lua              — :checkhealth lumiris
scripts/
  run_tests.lua           — headless mini.test ランナー (cquit で exit code 伝播)
  minitest_init.lua       — 対話用 bootstrap
tests/lumiris/test_*.lua  — mini.test spec
.github/workflows/ci.yml  — test (ubuntu/macos/windows × stable/nightly, per-file ループ) + stylua lint
```

### 依存方向

- `plugin/lumiris.lua` → `command.lua` → `colorscheme.lua` / `state.lua` / `log.lua`
- `init.lua.setup()` → `config.lua` → `command.lua` / `autocmd.lua` → `colorscheme.lua`
- `colorscheme.lua` → `config.lua` / `state.lua` / `log.lua`
- `health.lua` → `config.lua` / `state.lua` / `colorscheme.lua`

### ローテーションのコア (`colorscheme.lua`)

- `candidates()`: `getcompletion("", "color")` を `include`(allowlist) / `exclude` / `hated` でフィルタ。
- `pick(current)`: 重み付きランダム。like score + 1 を選択重み (下限 1) にし、`current` は候補が 2 つ以上ある時だけ除外して連続同色を防ぐ。
- `apply(name)`: `pcall(vim.cmd.colorscheme, name)`。失敗は `log.warn` で握って false を返し、`rotate()` が別候補を試す (最大 5 回)。`background` 設定があれば適用前に `&background` をセット。
- `rotate(opts)`: timer / autocmd が引数なしで呼ぶ。`interval` ゲート (前回 apply から `interval` 秒未満なら skip。`vim.uv.now()` の ms で計測) と `enabled` を見る。`force = true` (= `:LumirisChange`) は両ゲートを無視。`prime()` は register 時に clock を現在時刻で初期化し、起動直後の最初の event で即切り替わるのを防ぐ。

## 設計原則

- **Resilience.** colorscheme の apply 失敗 (壊れた scheme 等) は `log.warn` で握って次候補にフォールバック。timer/autocmd callback は常に消化し Neovim を止めない。timer callback は必ず `vim.schedule` でラップして API を触る。
- **Notify / log_level ゲート契約.** background の `vim.notify` は直書きせず必ず `log.at` 系を経由。`notify = false` は完全無音。ユーザ起点コマンドのフィードバックのみ `log.echo` (常に表示)。
- **テスト先行.** 挙動変更・バグ修正は先に `tests/lumiris/test_*.lua` に再現を書いてから実装。mini.test の `MiniTest.new_set` / `hooks.pre_case` / `MiniTest.expect.equality` / `MiniTest.skip` を使う。state を触る spec は `state_path = vim.fn.tempname()` + `package.loaded["lumiris.state"] = nil` でキャッシュを落として隔離する。
- **Windows 特性.** CI に `windows-latest` あり。`state_path` のパス区切り / `vim.fn.mkdir(..., "p")` / `stdpath("state")` の差異に注意。テストは `nvim -u NONE -l` で全 OS 共通。

## 移植元との差分 (denops 版からの設計変更)

- TOML 設定/嗜好 → `setup()` テーブル (static) + JSON (prefs) に分離。
- `g:lumiris_*` グローバル → `setup()` テーブル一本。
- `debug` boolean → `log_level` + `notify` ゲート。
- 連続同色回避と like/hate の重み付き選択を `pick()` に明示実装。
- Deno/denops ランタイム依存を排除 (in-process Lua、`vim.uv` timer)。
