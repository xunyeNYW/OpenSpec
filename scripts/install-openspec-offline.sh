#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

usage() {
  cat <<'EOF'
OpenSpec 离线安装脚本

默认行为：把 OpenSpec 安装到用户目录（不需要 sudo），并在 ~/.local/bin 创建 openspec 命令。

用法：
  1) 从 tgz 安装
     ./install-openspec-offline.sh --bundle /path/openspec-cli-offline-vX.Y.Z.tgz

  2) 在已解压目录里安装（更常见）
     tar -xzf openspec-cli-offline-vX.Y.Z.tgz
     cd openspec-cli-offline-...   # 解压后目录视 tgz 内容而定
     ./install-openspec-offline.sh

可选参数：
  --bundle <tgz>        指定离线 bundle tgz；不传则假定当前目录就是 bundle 根目录
  --install-dir <dir>  安装到的目录（默认：$HOME/.local/openspec）
  --bin-dir <dir>       创建 wrapper 的目录（默认：$HOME/.local/bin）
  --no-link             不创建 openspec 全局 wrapper（只拷贝到 install-dir）
  --force               install-dir 已存在时也覆盖
  --help                显示帮助
EOF
}

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/openspec}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
BUNDLE_PATH=""
NO_LINK=0
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle)
      BUNDLE_PATH="${2:-}"
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="${2:-}"
      shift 2
      ;;
    --bin-dir)
      BIN_DIR="${2:-}"
      shift 2
      ;;
    --no-link)
      NO_LINK=1
      shift 1
      ;;
    --force)
      FORCE=1
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数：$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "缺少必要文件：$f" >&2
    exit 1
  fi
}

node_version_ok() {
  # 项目要求：Node >= 20.19.0
  local ver major minor patch
  ver="$(node -p "process.versions.node")"
  IFS='.' read -r major minor patch <<<"$ver"
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"

  if (( major > 20 )); then return 0; fi
  if (( major < 20 )); then return 1; fi
  if (( minor > 19 )); then return 0; fi
  if (( minor < 19 )); then return 1; fi
  if (( patch >= 19 )); then return 0; fi
  return 1
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

SRC_ROOT=""
if [[ -n "$BUNDLE_PATH" ]]; then
  if [[ ! -f "$BUNDLE_PATH" ]]; then
    echo "bundle 不存在：$BUNDLE_PATH" >&2
    exit 1
  fi
  TMP_DIR="$(mktemp -d)"
  tar -xzf "$BUNDLE_PATH" -C "$TMP_DIR"
  SRC_ROOT="$TMP_DIR"
else
  SRC_ROOT="$(pwd)"
fi

require_file "$SRC_ROOT/package.json"
require_file "$SRC_ROOT/bin/openspec.js"

if ! command -v node >/dev/null 2>&1; then
  echo "未找到 Node.js。请先安装 Node.js（要求 >= 20.19.0）" >&2
  exit 1
fi
if ! node_version_ok; then
  echo "Node.js 版本不满足要求：当前为 $(node -v)，需要 >= 20.19.0" >&2
  exit 1
fi

if [[ -d "$INSTALL_DIR" && "$FORCE" -ne 1 ]]; then
  if [[ -f "$INSTALL_DIR/bin/openspec.js" ]]; then
    echo "安装目录已存在：$INSTALL_DIR（如需覆盖请加 --force）" >&2
    exit 1
  fi
fi

if [[ -d "$INSTALL_DIR" && "$FORCE" -eq 1 ]]; then
  rm -rf "$INSTALL_DIR"
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
mkdir -p "$INSTALL_DIR"

# 拷贝 bundle 根目录内容到 INSTALL_DIR
cp -a "$SRC_ROOT"/. "$INSTALL_DIR"/

if [[ "$NO_LINK" -eq 1 ]]; then
  echo "安装完成：$INSTALL_DIR"
  exit 0
fi

mkdir -p "$BIN_DIR"
WRAPPER_PATH="$BIN_DIR/openspec"

cat >"$WRAPPER_PATH" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec node "$(printf "%q" "$INSTALL_DIR")/bin/openspec.js" "\$@"
EOF
chmod +x "$WRAPPER_PATH"

echo "安装完成：$INSTALL_DIR"
echo "命令 wrapper：$WRAPPER_PATH"
echo "验证：$WRAPPER_PATH --version"
"$WRAPPER_PATH" --version

