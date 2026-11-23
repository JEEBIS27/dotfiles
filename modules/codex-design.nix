{ pkgs, ... }:
let
  source = repo: rev: sha256: builtins.fetchTarball {
    url = "https://codeload.github.com/${repo}/tar.gz/${rev}";
    inherit sha256;
  };
  impeccable = source "pbakaus/impeccable"
    "b49177d32788f2dc585c42831d845dacf1ebed2c" "1y14bdf3vlxwww7gsjxc3fj4k7bqjw9f9rwb4pwdwpz7sf293ndy";
  vercel = source "vercel-labs/agent-skills"
    "5a37a6329fbad3666c3207392a6a7c0110e92efb" "0hbg1yw4j476lav5r4k7w165n993cdjjhhidvcgmrfv7jb49qrl0";
  emil = source "emilkowalski/skill"
    "64eb3deb9a5fbfa041faf783e0bc3fd635872e9c" "1w8gd78rrh82hwq7h1pc1lq9g79rrj0n1y31j3ggppi7yyadp6fd";
  arch = { x86_64-linux = "x64"; aarch64-linux = "arm64"; }.${pkgs.stdenv.hostPlatform.system};
  asset = "impeccable-linux-${arch}";
  engine = pkgs.fetchurl {
    url = "https://github.com/pbakaus/impeccable/releases/download/engine-v0.1.27/${asset}";
    sha256 = { x64 = "41d66e945bcdfc560005b61ad0b6b2312b124890039262f2e63322ef2709ccfd";
      arm64 = "6ceb6188c80adb4b4fcc0721e677e2124d795b8e243599ad0d7bea33369b2c9c"; }.${arch};
  };
in {
  home.file = {
    ".codex/AGENTS.md".source = ../files/codex/AGENTS.md;
    ".agents/skills/impeccable".source = pkgs.runCommand "impeccable-codex-skill" {} ''
      cp -R ${impeccable}/.agents/skills/impeccable "$out"
      chmod u+w "$out/scripts"
      install -Dm755 ${engine} "$out/scripts/bin/linux-${arch}/impeccable"
    '';
    ".agents/skills/web-design-guidelines".source = "${vercel}/skills/web-design-guidelines";
    ".agents/skills/emil-design-eng".source = "${emil}/skills/emil-design-eng";
  };
}
