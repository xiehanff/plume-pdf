# plume_ai_chat

Reusable AI chat package for Flutter applications.

The package owns generic conversation models, turn/session lifecycle, streaming cancellation and GetX-based UI state coordination. Host applications remain responsible for domain context such as PDF extraction, OCR, selected regions, credentials persistence and app routing.

## Dependency direction

```text
Host domain adapter
        ↓
AiChatController (GetX)
        ↓
AiChatSession
        ↓
AiBackend
```

`AiChatSession` and `AiBackend` do not depend on GetX. GetX is limited to the controller/UI state layer.
