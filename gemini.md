# Gemini 利用ガイド

Claude Code から `gemini-cli` MCP 経由で Gemini を呼び出す際の指針。

## アーキテクチャ

```
Claude Code → mcp__gemini-cli__ask-gemini → Gemini API
                                           (GCP Extensions / Google Search)
```

Gemini の返答は **Claude のコンテキストに入力トークンとして流れ込む**。
節約できるのは「Gemini が内部で処理する部分」のみであり、返答自体は Claude が消費する。

---

## 呼び出すべきケース

### GCP 操作
Gemini に GCP エクステンション（cloud-resource-manager, cloud-run 等）が入っているため、
複数の GCP API 呼び出しを Gemini 内部で連鎖させ、**要約だけ**を受け取ると効率が良い。

```
例: "GCP プロジェクト foo-prod の Cloud Run サービス一覧と、
    各サービスの最新リビジョンのステータスを200字以内で返して"
```

### 外部文献・Web 検索
Google Search グラウンディングを活かした一発検索に向く。
反復的な調査（結果を見て次の検索を決める）には向かない。

```
例: "transformerアーキテクチャにおける attention head pruning の
    2024年以降の主要手法を箇条書き5点で返して"
```

---

## 呼び出さないケース

| ケース | 理由 |
|---|---|
| 反復的な調査（中間結果を見て次の検索を決める） | 往復ごとに Claude のコンテキストが蓄積する |
| ファイル編集・git 操作を伴うタスク | Claude Code が直接実行する方が速い |
| 短い Q&A（自明な回答） | 呼び出しオーバーヘッドが無駄 |

---

## プロンプト設計のルール

1. **返答の長さを必ず指定する** — 指定しないと冗長な返答が Claude の入力トークンを増やす
   - `"〇〇字以内で返して"` / `"箇条書き N 点で"` / `"JSON で返して"`

2. **中間ステップを隠蔽させる** — Gemini に複数の操作をまとめて依頼し、最終結果だけ要求する
   - BAD: `"Cloud Run の一覧を取得して"` → `"その中から停止中のものを絞り込んで"` (2往復)
   - GOOD: `"Cloud Run サービスのうち停止中のものだけ一覧で返して"` (1往復)

3. **モデルを意識する** — `GEMINI_MODEL` 環境変数で Gemini 2.0 Flash 等の安価なモデルを指定すると
   Google API コストも抑えられる

---

## ツール一覧

| ツール | 用途 |
|---|---|
| `mcp__gemini-cli__ask-gemini` | 調査・Q&A・GCP 操作・文献検索 |
| `mcp__gemini-cli__brainstorm` | アイデア出し・構成案 |
| `mcp__gemini-cli__fetch-chunk` | URL の内容を取得（大きなドキュメント対応）|

---

## トークン節約の期待値

- **大きく節約できる**: GCP の複数リソース操作を 1 回の Gemini 呼び出しにまとめた場合
- **中程度**: 文献検索（返答を短く制約した場合）
- **ほぼ節約されない**: 反復的な調査、冗長な返答をそのまま受け取った場合

主な恩恵は「Anthropic 課金 → Google 課金への移転」。
Gemini 無料枠・Flash モデルを使うとコスト削減効果が出やすい。
