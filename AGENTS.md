# Agent Operating Guide

## Mission

Maintain two native iOS keyboard projects without weakening privacy, user control, buildability, or factual documentation.

## Project map

- `Apps/CarinaType`: Foundation Models keyboard and host app.
- `Apps/MayaType`: deterministic suggestion keyboard and host app.
- `Docs`: architecture, privacy, and verification evidence.
- `Scripts/verify.sh`: required local validation.

## Non-negotiable invariants

1. Keep `RequestsOpenAccess` set to `false` in both keyboard extension plists.
2. Do not add networking, analytics, tracking, remote logging, or secret storage.
3. Never send a message or place a call automatically.
4. Insert only user-reviewed text through the keyboard's `textDocumentProxy`.
5. Keep CARINA model calls availability-gated for iOS 26 or later.
6. Describe MAYA as deterministic; do not claim that it uses a language model.
7. State that Apple Speech recognition may use Apple speech services.
8. Never commit signing identities, provisioning profiles, tokens, or `.env` files.

## Required workflow

1. Read the affected source and relevant file in `Docs`.
2. Make the smallest complete change.
3. Run `./Scripts/verify.sh`.
4. Update documentation when behavior or a public claim changes.
5. Report the exact command and result; never claim unperformed device or App Store verification.

## Swift rules

- Prefer SwiftUI for host screens and native UIKit/SwiftUI extension APIs.
- Use availability checks around APIs newer than the deployment target.
- Keep UI state updates on the main actor or main queue.
- Handle failures explicitly and present actionable user-facing status.
- Preserve accessibility labels, high contrast, and Dynamic Type behavior.

## Definition of done

- Both unsigned simulator builds pass.
- Privacy verification passes.
- No secret-like files or generated build products are tracked.
- README and documentation claims match the implementation.
