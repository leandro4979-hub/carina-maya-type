# Architecture

## CARINA TYPE

CARINA contains a SwiftUI host app and a custom keyboard extension. The extension maintains a local draft, offers explicit transformation actions, and—on iOS 26 or later—uses `SystemLanguageModel.default` through a `LanguageModelSession`. Generated text returns to the draft so the user can review it before insertion.

The extension handles unavailable models and unsupported operating systems as visible states. It does not fall back to a remote model.

## MAYA TYPE

MAYA contains a SwiftUI host app and a UIKit custom keyboard extension. It examines the locally available draft and selects prepared response choices using deterministic keyword rules. It does not call a language model.

## Shared boundary

Each keyboard is an extension embedded in its own host app. Both extension plists set `RequestsOpenAccess` to false. Text insertion uses Apple's `UIKeyInput` keyboard path through `textDocumentProxy` and remains initiated by the user.

The host apps include optional voice screens. Speech recognition uses `SFSpeechRecognizer`; CARINA can read a prepared response with `AVSpeechSynthesizer`. These host-app features are separate from keyboard model generation.
