#!/usr/bin/env bash
set -euo pipefail

# Build OpenSpec 离线发布包（B-1 瘦包 + B-2 全量离线 bundle）
# 用法：./scripts/build-release.sh [--clean]

CLEAN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) CLEAN=1; shift ;;
    *) echo "未知参数：$1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/releases"

VERSION="$(node -p "JSON.parse(require('fs').readFileSync('$ROOT_DIR/package.json','utf8')).version")"

echo "=== OpenSpec Release Build v$VERSION ==="

cd "$ROOT_DIR"

# 清理旧产物
if [[ "$CLEAN" -eq 1 ]]; then
  echo "[1/5] 清理旧产物..."
  rm -rf "$BUILD_DIR/online" "$BUILD_DIR/offline"
fi
mkdir -p "$BUILD_DIR/online" "$BUILD_DIR/offline"

# 构建 TypeScript
echo "[2/5] 构建 TypeScript..."
pnpm run build

# B-1: 瘦 tgz（不含 node_modules，用户安装时需要联网拉依赖）
echo "[3/5] 生成瘦包 (online)..."
pnpm pack --pack-destination "$BUILD_DIR/online"
# 重命名为正式名称
find "$BUILD_DIR/online" -name "*.tgz" -exec mv {} "$BUILD_DIR/online/openspec-cli-v$VERSION.tgz" \;

# B-2: 离线全量 bundle（含 node_modules + 安装脚本）
echo "[4/5] 生成离线 bundle (offline)..."

# 临时构建目录
TMP_DIR="$(mktemp -d)"
trap "rm -rf $TMP_DIR" EXIT

# 拷贝必要文件
cp package.json "$TMP_DIR/"
cp -r dist bin schemas "$TMP_DIR/"

# 拷贝安装脚本（主脚本 + 兼容转发）
cp "$SCRIPT_DIR/install-openspec-offline.sh" "$TMP_DIR/install-openspec-offline.sh"

# 安装生产依赖（离线，不跑 postinstall）
(cd "$TMP_DIR" && CI=true OPENSPEC_NO_COMPLETIONS=1 pnpm install --prod --ignore-scripts)

# 打包
tar -czf "$BUILD_DIR/offline/openspec-cli-offline-v$VERSION.tgz" -C "$TMP_DIR" .

echo "[5/5] 完成！"

echo ""
echo "产物："
echo "  - 瘦包 (online): $BUILD_DIR/online/openspec-cli-v$VERSION.tgz"
echo "  - 离线 bundle (offline): $BUILD_DIR/offline/openspec-cli-offline-v$VERSION.tgz"
echo ""
echo "验证 offline 安装："
echo "  tar -xzf $BUILD_DIR/offline/openspec-cli-offline-v$VERSION.tgz -C /tmp"
echo "  cd /tmp/<解压目录>"
echo "  ./install-openspec-offline.sh --install-dir /tmp/openspec-test --bin-dir /tmp/openspec-bin"
echo "  /tmp/openspec-bin/openspec --version"