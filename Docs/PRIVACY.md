# Privacy boundaries

## Enforced in source

- Both keyboard extensions declare `RequestsOpenAccess` as `false`.
- No networking framework or remote API client is part of either keyboard.
- No analytics or tracking SDK is included.
- CARINA uses Apple's system language model when it is locally available.
- MAYA uses deterministic local suggestion rules.
- Prepared text is inserted only after a user action.
- Neither app sends a message or places a call.

## Important qualification

The optional voice screens use Apple's Speech framework. Speech recognition availability and processing are controlled by Apple and may involve Apple speech services. For that reason, this project does not claim that every voice interaction is fully offline.

## Regression check

Run `./Scripts/verify-privacy.sh`. The check fails if Full Access becomes enabled or if common networking imports appear in the keyboard source.
