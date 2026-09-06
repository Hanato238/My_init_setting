# cargo (crates.io) から入れるツール。install/update 兼用で `cargo install <pkg> --locked`。
# 現在は空。bws は MSVC リンカ無しでは `cargo install` できないため、ビルド済みバイナリを
# 配る packages/local/bws/ (ローカル choco パッケージ) へ移動した。
$cargoPackages = @()
