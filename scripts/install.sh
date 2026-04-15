#!/usr/bin/env bash
# install.sh — LARC local install script
#
# 使い方 (通常):
#   bash scripts/install.sh           # リポジトリ内から実行（開発者向け）
#
# 使い方 (curl インストーラー):
#   curl -fsSL https://raw.githubusercontent.com/ShunsukeHayashi/lark-agent-runtime/main/scripts/install.sh | bash
#   → ~/.larc/runtime/ にクローンしてシンボリックリンクを作成する

set -uo pipefail

INSTALL_TARGET="/usr/local/bin/larc"
RUNTIME_DIR="${LARC_RUNTIME_DIR:-$HOME/.larc/runtime}"
REPO_URL="https://github.com/ShunsukeHayashi/lark-agent-runtime.git"

# Colors
_RED='\033[0;31m'; _GREEN='\033[0;32m'; _YELLOW='\033[1;33m'
_BLUE='\033[0;34m'; _CYAN='\033[0;36m'; _BOLD='\033[1m'; _RESET='\033[0m'

_ok()   { echo -e "${_GREEN}✓${_RESET} $*"; }
_fail() { echo -e "${_RED}✗${_RESET} $*"; }
_warn() { echo -e "${_YELLOW}!${_RESET} $*"; }
_info() { echo -e "${_BLUE}·${_RESET} $*"; }

echo ""
echo -e "${_BOLD}${_CYAN}LARC Installer${_RESET}"
echo "──────────────────────────────"
echo ""

# ── 0. Detect execution context ──────────────────────────────────────────────
# curl パイプ実行か、リポジトリ内から実行かを判別する
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  LARC_REPO_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")/.." && pwd)"
else
  # curl | bash で実行された場合（BASH_SOURCE が空）
  LARC_REPO_DIR=""
fi

# ── 1. Check dependencies ────────────────────────────────────────────────────

_info "Checking dependencies..."

MISSING=0

if command -v bash &>/dev/null; then
  _ok "bash $(bash --version | head -1 | awk '{print $4}')"
else
  _fail "bash not found"; MISSING=$((MISSING+1))
fi

if command -v python3 &>/dev/null; then
  _ok "python3 $(python3 --version 2>&1 | awk '{print $2}')"
else
  _fail "python3 not found — required for IM poller and ingress pipeline"; MISSING=$((MISSING+1))
fi

if command -v lark-cli &>/dev/null; then
  _ok "lark-cli $(lark-cli --version 2>/dev/null || echo '(version unknown)')"
else
  _warn "lark-cli not found — install with: npm install -g @larksuite/cli"
  _info "Continuing install; lark-cli is required at runtime"
fi

if command -v node &>/dev/null; then
  _ok "node $(node --version)"
else
  _warn "node not found — needed to install lark-cli via npm"
fi

if [[ "$MISSING" -gt 0 ]]; then
  echo ""
  _fail "$MISSING required dependency/dependencies missing. Please install them and re-run."
  exit 1
fi

echo ""

# ── 2. Clone or update repo into ~/.larc/runtime/ ────────────────────────────

if [[ -z "$LARC_REPO_DIR" ]]; then
  # curl | bash: リポジトリが手元にないのでクローンする
  _info "Downloading LARC into ${RUNTIME_DIR} ..."

  if [[ -d "$RUNTIME_DIR/.git" ]]; then
    _info "既存の runtime が見つかりました。git pull で更新します..."
    if git -C "$RUNTIME_DIR" pull --ff-only origin main 2>&1 | sed 's/^/  /'; then
      _ok "LARC runtime 更新完了"
    else
      _warn "git pull に失敗しました。既存ファイルをそのまま使用します"
    fi
  else
    mkdir -p "$(dirname "$RUNTIME_DIR")"
    if git clone --depth 1 "$REPO_URL" "$RUNTIME_DIR" 2>&1 | sed 's/^/  /'; then
      _ok "LARC runtime クローン完了 → $RUNTIME_DIR"
    else
      _fail "クローンに失敗しました: $REPO_URL"
      exit 1
    fi
  fi

  LARC_REPO_DIR="$RUNTIME_DIR"

else
  # リポジトリ内から実行: ソースをそのまま使うが、runtime dir にコピーしておく
  if [[ "$LARC_REPO_DIR" != "$RUNTIME_DIR" ]]; then
    _info "ソースを ${RUNTIME_DIR} に同期します（エージェント保護用）..."
    mkdir -p "$RUNTIME_DIR"
    # .git も含めてコピー（larc update が git pull できるように）
    rsync -a --delete \
      --exclude='.claude/skills/' \
      "$LARC_REPO_DIR/" "$RUNTIME_DIR/" 2>/dev/null || \
    cp -r "$LARC_REPO_DIR/." "$RUNTIME_DIR/"
    _ok "同期完了 → $RUNTIME_DIR"
  else
    _ok "既に runtime dir から実行しています: $RUNTIME_DIR"
  fi
fi

echo ""

# ── 3. Install Claude Code skills ────────────────────────────────────────────

CLAUDE_SKILLS_SRC="$LARC_REPO_DIR/.claude/skills"
CLAUDE_SKILLS_DST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

_info "Installing Claude Code skills..."

if [[ ! -d "$CLAUDE_SKILLS_SRC" ]]; then
  _warn "No skills directory found at $CLAUDE_SKILLS_SRC (skipping)"
else
  mkdir -p "$CLAUDE_SKILLS_DST"
  skill_count=0
  for skill_dir in "$CLAUDE_SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")
    dst="$CLAUDE_SKILLS_DST/$skill_name"
    if [[ -d "$dst" ]]; then
      cp -r "$skill_dir/." "$dst/" 2>/dev/null && skill_count=$((skill_count+1))
    else
      cp -r "$skill_dir" "$dst" && skill_count=$((skill_count+1))
    fi
  done
  _ok "$skill_count skills installed → $CLAUDE_SKILLS_DST"
fi

echo ""

# ── 4. Symlink larc binary ───────────────────────────────────────────────────

LARC_BIN="$RUNTIME_DIR/bin/larc"

if [[ ! -f "$LARC_BIN" ]]; then
  _fail "bin/larc not found at $LARC_BIN"
  exit 1
fi

chmod +x "$LARC_BIN"

if [[ -L "$INSTALL_TARGET" ]] && [[ "$(readlink "$INSTALL_TARGET")" == "$LARC_BIN" ]]; then
  _ok "larc already symlinked at $INSTALL_TARGET"
elif [[ -e "$INSTALL_TARGET" ]]; then
  _warn "$INSTALL_TARGET exists and is not a symlink to this install"
  _info "To overwrite: sudo ln -sf $LARC_BIN $INSTALL_TARGET"
else
  if ln -sf "$LARC_BIN" "$INSTALL_TARGET" 2>/dev/null; then
    _ok "Installed larc → $INSTALL_TARGET"
  else
    _warn "Permission denied. Trying with sudo..."
    if sudo ln -sf "$LARC_BIN" "$INSTALL_TARGET"; then
      _ok "Installed larc → $INSTALL_TARGET (via sudo)"
    else
      _fail "Could not install to $INSTALL_TARGET"
      _info "Manual install: sudo ln -sf $LARC_BIN $INSTALL_TARGET"
      exit 1
    fi
  fi
fi

echo ""

# ── 5. Verify larc is callable ───────────────────────────────────────────────

if larc version &>/dev/null; then
  _ok "larc $(larc version) is callable from PATH"
else
  _warn "larc installed but 'larc version' returned non-zero (config may not be set up yet)"
fi

echo ""

# ── 6. Check for existing config ─────────────────────────────────────────────

LARC_HOME="${LARC_HOME:-$HOME/.larc}"
CONFIG_FILE="$LARC_HOME/config.env"

if [[ -f "$CONFIG_FILE" ]]; then
  _ok "Config found at $CONFIG_FILE"

  missing_vars=()
  for var in LARC_DRIVE_FOLDER_TOKEN LARC_BASE_APP_TOKEN; do
    if ! grep -q "^${var}=" "$CONFIG_FILE" 2>/dev/null; then
      missing_vars+=("$var")
    fi
  done

  if [[ "${#missing_vars[@]}" -gt 0 ]]; then
    _warn "Config exists but missing required vars: ${missing_vars[*]}"
    _info "Run 'larc quickstart' to complete setup"
  else
    _ok "All required config vars present"
  fi
else
  _warn "No config found at $CONFIG_FILE"
  echo ""
  echo -e "  Run ${_BOLD}larc quickstart${_RESET} to complete first-time setup"
fi

echo ""
echo -e "${_GREEN}${_BOLD}LARC installed successfully.${_RESET}"
echo ""
echo -e "  ${_BOLD}Runtime location (read-only):${_RESET} $RUNTIME_DIR"
echo -e "  ${_BOLD}Command:${_RESET}                    /usr/local/bin/larc → $LARC_BIN"
echo ""
echo -e "  ${_BOLD}Quick start:${_RESET}"
echo "    lark-cli config init --app-id <App ID> --app-secret-stdin --brand lark"
echo "    lark-cli auth login"
echo "    larc quickstart       # 自動セットアップ（初回はこれだけ）"
echo "    larc status           # 状態確認"
echo "    larc update           # 最新版に更新"
echo ""
echo -e "  ${_YELLOW}※ $RUNTIME_DIR は読み取り専用です。直接編集しないでください。${_RESET}"
echo -e "  ${_YELLOW}  更新は 'larc update' で行ってください。${_RESET}"
echo ""
