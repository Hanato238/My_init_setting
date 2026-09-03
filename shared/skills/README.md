# shared/skills

Claude Code / Gemini CLI などエージェント共通の skill 定義の配布元。

`shared/mcp.d` と同じ役割で、ここが各 skill の正本（source of truth）。
現時点では各プラットフォーム側（`.claude/skills`, `.agents/skills`,
`claude_container_template/.claude/skills` など）への自動同期スクリプトは
未実装のため、既存の配置先ディレクトリはそれぞれ手動コピーのまま残っている。

skill を追加・更新する場合は、まずここに追加してから、必要な配置先に
手動でコピーすること。
