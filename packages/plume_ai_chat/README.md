# plume_ai_chat

Reusable Flutter AI chat foundation used by Plume applications.

The package owns generic conversation state, streaming lifecycle, provider transport boundaries and GetX-based UI coordination. Host applications remain responsible for domain context such as PDF extraction/OCR, app routing and credential persistence.

## Architecture

```text
Host domain adapter
        ↓
AiChatController (GetX)
        ↓
AiChatSession
        ↓
AiBackend
        ↓
DeepSeekBackend / another provider
```

`AiChatSession` and `AiBackend` are framework-independent. GetX is an intentional dependency of the controller/UI layer, not of the transport/runtime layer.

The package does **not** call `Get.put`, `Get.find`, define routes, or persist credentials. The host owns controller lifecycle and dependency registration.

## Basic usage

```dart
final session = AiChatSession(
  backend: DeepSeekBackend(),
);

final controller = AiChatController(session: session);

final result = await controller.send(
  apiKey: apiKey,
  input: const AiChatInput(text: 'Hello'),
  systemPrompt: 'Answer concisely.',
);
```

A host that already uses GetX may register the controller itself:

```dart
Get.put<AiChatController>(controller, tag: 'my-chat');
```

Registration is optional; the same controller can also be passed directly to widgets.

## Streaming and cancellation

`AiChatSession` owns:

- ordered conversation history
- a Turn barrier so a new request never snapshots half-finished history
- active stream cancellation
- Stop-before-first-token rollback
- partial-answer commit after Stop
- generation invalidation when starting a new conversation
- ~40 ms preview batching for high-frequency SSE streams
- latest-wins turns for tool/action workflows

The public history view is immutable.

## Domain adapters

Provider transport and domain context are separate concerns. For example Plume PDF keeps these outside this package:

```text
PDF selection / OCR / page text
             ↓
      PdfAiChatSession
             ↓
       AiChatSession
```

`PdfAiChatSession` converts PDF-specific actions into generic chat turns. The package itself has no dependency on `pdfrx`, PDF models or OCR APIs.

## Provider-specific options

Generic output limits use `AiRequestOptions.maxOutputTokens`. Provider-only options stay inside `providerOptions` so they do not leak into the core runtime.

```dart
const AiRequestOptions(
  maxOutputTokens: 32768,
  providerOptions: <String, Object?>{
    'reasoning_effort': null,
  },
)
```

For `DeepSeekBackend`, an explicit `reasoning_effort: null` omits that field from the request; if the key is absent, the backend default is used.

## Package boundary

Belongs in `plume_ai_chat`:

- chat input/history/presentation models
- response/follow-up parsing
- session and Turn lifecycle
- provider-neutral backend contract
- DeepSeek HTTP/SSE backend
- GetX chat controller
- generic chat UI behavior such as follow-tail scrolling

Belongs in the host application:

- PDF/document extraction and OCR
- app navigation
- sidebar/window layout
- API key persistence / secure storage policy
- app-specific colors, fonts and Markdown presentation
- provider/account selection policy specific to the product
