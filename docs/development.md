# 開発環境の管理

言語本体・ビルドツールはNixで管理する。共通のPython、Node.js（npm同梱）、Rust（Cargo・rustfmt・Clippy）、GoとuvをHome Managerで導入し、バージョンはflake.lockのnixpkgs-appsで固定する。更新は `just update-apps`、設定の適用は `just switch`。

## 固定済み環境を使う

```bash
nix develop ~/dotfiles#python
nix develop ~/dotfiles#node
nix develop ~/dotfiles#rust
nix develop ~/dotfiles#go
nix develop ~/dotfiles
```

最後のコマンドは全言語入り。開発シェルも同じロックを使用する。

## プロジェクト単位で管理する

独立したプロジェクトでは次のflake.nixを配置し、必要な言語とシステム依存をpackagesに指定する。Pythonの別系列は `python313` など、Nodeの別系列は `nodejs_22` など、利用するNixpkgsに存在する属性を選ぶ。パッチバージョンはflake.lockで固定される。

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  outputs = { nixpkgs, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [ pkgs.python3 pkgs.uv pkgs.nodejs pkgs.pkg-config ];
      UV_PYTHON_DOWNLOADS = "never";
      UV_PYTHON_PREFERENCE = "only-system";
    };
  };
}
```

`.envrc` に `use flake` と記述し、`nix flake lock`、`direnv allow` を実行する。Git管理中なら新規Nixファイルを先に `git add flake.nix` する。以後fishで移動すると自動で切り替わり、離れると元に戻る。`.envrc`・flake.nix・flake.lockをコミットし、`.direnv/`・`.venv/`・node_modules/を除外する。更新はプロジェクト内で `nix flake update`。

Pythonの依存は `uv init`、`uv add パッケージ名`、`uv sync`、`uv run python` で扱う。pyproject.tomlとuv.lockをコミットする。uvによるPython本体のダウンロードは無効。要求するPythonが見つからない場合はNixのpackagesを変更する。Nodeはpackage.jsonとpackage-lock.json、RustはCargo.tomlとCargo.lock、Goはgo.modとgo.sumも管理する。

## Nixで対応できない場合のmise

mise自体はNixで導入する。グローバルな言語登録やシェルの自動activateは行わない。必要なプロジェクトでのみ `mise use ツール名@正確なバージョン`、`mise install`、`mise exec -- コマンド` を使い、mise.tomlと生成されたmise.lockをコミットする。

自動切り替えが必要なら、そのプロジェクトの.envrcを `use mise` にして `direnv allow` を実行する。Nixと同じ言語を二重に指定しない。NixOSで配布バイナリの動的リンクが通らない場合は、Nixのパッケージ化や実行環境の調整も必要になる。

## Docker（NixOS）

Docker Engine・Compose・BuildxをNixOS側で導入し、nixpkgs-appsのロックでバージョンを固定する。Dockerは必要時にソケット経由で起動する。利用にはsudoを使う。設定の反映は `just switch`。

```bash
sudo docker version
sudo docker compose version
sudo docker buildx version
sudo docker run --rm hello-world
```

コンテナ・イメージ・ボリュームはDockerが管理する。Nixによるイメージやボリュームの自動削除は設定しない。
