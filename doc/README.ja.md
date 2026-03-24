# ROS 1 Bridge Docker Environment

**[English](../README.md)** | **[繁體中文](README.zh-TW.md)** | **[简体中文](README.zh-CN.md)** | **[日本語](README.ja.md)**

> **TL;DR** — `osrf/ros:foxy-ros1-bridge` ベースの ROS 1/2 ブリッジコンテナ。`parameter_bridge` で ROS 1 (Noetic) と ROS 2 (Foxy) の topic をブリッジ。
>
> ```bash
> ./build.sh && ./run.sh
> ```

---

## 目次

- [特徴](#特徴)
- [クイックスタート](#クイックスタート)
- [使い方](#使い方)
- [ブリッジ設定](#ブリッジ設定)
- [アーキテクチャ](#アーキテクチャ)
- [ディレクトリ構成](#ディレクトリ構成)

---

## 特徴

- **ビルド済み bridge イメージ**：`osrf/ros:foxy-ros1-bridge` ベース、ROS 1 と ROS 2 を同梱
- **Parameter bridge**：YAML 設定で topic ブリッジを構成可能
- **Smoke Test**：Bats テストで両 ROS 環境と bridge の可用性を検証
- **Docker Compose**：`compose.yaml` 一つでビルドと実行を管理
- **サンプル設定**：scan と camera のブリッジ設定ファイルを同梱

## クイックスタート

```bash
# 1. ビルド
./build.sh

# 2. 実行（ROS master が起動済みであること）
./run.sh

# 3. 起動中のコンテナに接続
./exec.sh
```

## 使い方

### ビルド

```bash
./build.sh                       # runtime をビルド（デフォルト）
./build.sh test                  # smoke test 付きビルド

docker compose build runtime     # 同等のコマンド
```

### 実行

```bash
./run.sh                         # デフォルトの bridge 設定で実行

# カスタム bridge モードを使用
docker compose run --rm runtime ros2 run ros1_bridge dynamic_bridge
```

### 起動中のコンテナに接続

```bash
./exec.sh
./exec.sh bash
```

## ブリッジ設定

デフォルトの bridge 設定は `bridge.yaml`。追加設定ファイルは `config/` ディレクトリ内：

| ファイル | 説明 |
|----------|------|
| `bridge.yaml` | デフォルト設定（LaserScan `/scan`） |
| `config/scan_bridge.yaml` | LaserScan bridge |
| `config/release_bridge.yaml` | Camera + depth topics bridge |

異なる設定で再ビルド：

```bash
docker compose build --build-arg BRIDGE_FILE=config/release_bridge.yaml runtime
```

### YAML フォーマット

```yaml
topics:
  - topic: /scan
    type: sensor_msgs/msg/LaserScan
    queue_size: 10
```

## アーキテクチャ

```mermaid
graph TD
    EXT1["bats/bats:latest"]:::external
    EXT2["alpine:latest"]:::external
    EXT3["osrf/ros:foxy-ros1-bridge"]:::external

    EXT1 --> bats-src["bats-src"]:::tool
    EXT2 --> bats-ext["bats-extensions"]:::tool

    EXT3 --> runtime["runtime\nentrypoint + bridge config"]:::stage

    bats-src --> test["test  ⚡ ephemeral\nsmoke_test/ ビルド後に破棄"]:::ephemeral
    bats-ext --> test
    runtime --> test

    classDef external fill:#555,color:#fff,stroke:#999
    classDef tool fill:#8B6914,color:#fff,stroke:#c8960c
    classDef stage fill:#1a5276,color:#fff,stroke:#2980b9
    classDef ephemeral fill:#6e2c00,color:#fff,stroke:#e67e22,stroke-dasharray:5 5
```

## Smoke Tests

```bash
./build.sh test
```

`smoke_test/ros_env.bats` — **8 テスト**。

<details>
<summary>クリックしてテスト詳細を表示</summary>

#### ROS 環境 (4)

| テスト項目 | 説明 |
|-----------|------|
| ROS 1 (noetic) | `setup.bash` が存在する |
| ROS 2 (foxy) | `setup.bash` が存在する |
| ROS 1 | 環境を source 可能 |
| ROS 2 | ROS 1 の後に source 可能 |

#### Bridge (2)

| テスト項目 | 説明 |
|-----------|------|
| `ros1_bridge` | パッケージが利用可能 |
| `bridge.yaml` | 設定ファイルが存在する |

#### システム (2)

| テスト項目 | 説明 |
|-----------|------|
| `entrypoint.sh` | 存在し実行可能 |
| `config/` | ディレクトリが存在する |

</details>

## ディレクトリ構成

```text
ros1_bridge/
├── compose.yaml                 # Docker Compose 定義
├── Dockerfile                   # マルチステージビルド（runtime + test）
├── build.sh                     # ビルドスクリプト
├── run.sh                       # 実行スクリプト
├── exec.sh                      # 起動中のコンテナに接続
├── entrypoint.sh                # ROS 1 + ROS 2 を source、bridge 設定を読み込み
├── bridge.yaml                  # デフォルト bridge 設定
├── config/                      # 追加 bridge 設定
│   ├── scan_bridge.yaml         # LaserScan bridge
│   └── release_bridge.yaml      # Camera + depth bridge
├── .github/workflows/           # CI/CD
│   ├── main.yaml
│   ├── build-worker.yaml
│   └── release-worker.yaml
└── smoke_test/                  # Bats 環境テスト
    ├── ros_env.bats
    └── test_helper.bash
```
