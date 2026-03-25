# OpenSpec 离线安装

适用于 **离线自包含 bundle**（`openspec-cli-offline-vX.Y.Z.tgz`），已内置 node_modules，无需联网。

## 前提

- Node.js >= 20.19.0
- 足够写入安装目录的权限（默认 `$HOME/.local`，无需 sudo）

## 安装

```bash
# 1. 解压
tar -xzf openspec-cli-offline-vX.Y.Z.tgz
cd <解压后的目录>

# 2. 运行安装脚本
chmod +x ./install-openspec-offline.sh
./install-openspec-offline.sh
```

验证：
```bash
openspec --version
```

## 自定义安装位置

```bash
./install-openspec-offline.sh --install-dir /opt/openspec --bin-dir /usr/local/bin
```

## 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--install-dir` | 安装目录 | `$HOME/.local/openspec` |
| `--bin-dir` | 命令目录 | `$HOME/.local/bin` |
| `--force` | 覆盖已安装目录 | - |
| `--no-link` | 仅拷贝，不创建命令 | - |

## 进阶

直接从 tgz 安装（无需先解压）：
```bash
./install-openspec-offline.sh --bundle /path/to/openspec-cli-offline-vX.Y.Z.tgz
```