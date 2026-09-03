# GUÍA MAESTRA v4 — Modelos LLM para SDD Gentle-AI

**Mayo 2026** · Guía unificada con criterios de selección por fase

| Fase          | Provider / Modelo                     | Ctx   | Effort |
|---------------|---------------------------------------|-------|--------|
| orchestrator  | openai/gpt-5.5                        | 1M    | medium |
| Fallback #2   | anthropic/claude-opus-4.7             | 1M    | medium |
| Fallback #3   | opencode-go/deepseek-v4-pro           | 1M    | medium |
| Fallback #4   | google/gemini-3.1-pro-preview         | 1M    | medium |
| init          | opencode-go/deepseek-v4-flash         | 1M    | low    |
| Fallback #2   | google/gemini-3.1-pro-preview         | 1M    | low    |
| Fallback #3   | nvidia/qwen/qwen3.5-397b-a17b         | 1M    | low    |
| Fallback #4   | opencode/deepseek-v4-flash-free       | 1M    | low    |
| onboard       | opencode-go/deepseek-v4-pro           | 1M    | low    |
| Fallback #2   | openai/gpt-5.4                        | 1M    | low    |
| Fallback #3   | opencode-go/qwen3.6-plus              | 128K  | low    |
| Fallback #4   | nvidia/qwen/qwen3.5-397b-a17b         | 1M    | low    |
| explore       | opencode-go/kimi-k2.6                 | 256K  | high   |
| Fallback #2   | anthropic/claude-opus-4.7             | 1M    | high   |
| Fallback #3   | opencode-go/deepseek-v4-pro           | 1M    | high   |
| Fallback #4   | nvidia/z-ai/glm-5.1                   | 200K  | high   |
| propose       | anthropic/claude-opus-4.7             | 1M    | high   |
| Fallback #2   | opencode-go/kimi-k2.6                 | 256K  | high   |
| Fallback #3   | openai/gpt-5.5                        | 1M    | high   |
| Fallback #4   | github-copilot/gemini-3.1-pro-preview | 1M    | high   |
| spec          | openai/gpt-5.3-codex                  | 1M    | medium |
| Fallback #2   | anthropic/claude-sonnet-4.5           | 200K  | medium |
| Fallback #3   | opencode-go/qwen3.6-plus              | 128K  | medium |
| Fallback #4   | nvidia/mistralai/devstral-2-123b      | 128K  | medium |
| design        | google/gemini-3.1-pro-preview         | 1M    | medium |
| Fallback #2   | openai/gpt-5.5                        | 1M    | medium |
| Fallback #3   | github-copilot/gemini-3.1-pro-preview | 1M    | medium |
| Fallback #4   | anthropic/claude-sonnet-4.5           | 200K  | medium |
| tasks         | openai/gpt-5.4-mini-fast              | 400K  | low    |
| Fallback #2   | opencode-go/deepseek-v4-flash         | 1M    | low    |
| Fallback #3   | opencode-go/qwen3.5-plus              | 128K  | low    |
| Fallback #4   | github-copilot/claude-haiku-4.5       | 200K  | low    |
| apply         | anthropic/claude-opus-4.7             | 1M    | high   |
| Fallback #2   | openai/gpt-5.3-codex                  | 1M    | high   |
| Fallback #3   | opencode-go/glm-5.1                   | 200K  | high   |
| Fallback #4   | nvidia/z-ai/glm-5.1                   | 200K  | high   |
| verify        | openai/gpt-5.5-pro                    | 400K  | xhigh  |
| Fallback #2   | anthropic/claude-opus-4.7             | 1M    | high   |
| Fallback #3   | opencode-go/deepseek-v4-pro           | 1M    | high   |
| Fallback #4   | openai/gpt-5.5                        | 1M    | high   |
| archive       | opencode-zen/opencode-zen             | —     | none   |
| Fallback #2   | openai/gpt-5.4-mini-fast              | 400K  | none   |
| Fallback #3   | opencode/big-pickle                   | —     | none   |
| Fallback #4   | github-copilot/claude-haiku-4.5       | 200K  | none   |
