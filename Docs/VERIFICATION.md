# Verification

## Automated checks

`./Scripts/verify.sh` performs:

1. privacy-invariant checks for both keyboard extensions;
2. an unsigned CARINA simulator build;
3. an unsigned MAYA simulator build.

GitHub Actions runs the same script on pushes and pull requests.

## Development evidence

Before the initial public release, both apps compiled for an iOS Simulator and a connected physical iPhone, and both application bundles launched on that device. This is development verification, not App Store review or certification.

## MAYA snippet verification

After registering `group.com.leandrofajardo.maya-type` for the app and keyboard targets, verify on a physical device:

1. Keep MAYA TYPE Full Access disabled.
2. Add `;sig` in the host app and assign replacement text.
3. Open a text field in another app, switch to MAYA TYPE, and type `;si`.
4. Confirm the snippet appears as a suggestion.
5. Tap it and confirm the typed trigger is replaced exactly once by the saved text.
6. Confirm existing built-in deterministic suggestions still appear when no snippet prefix is active.

The App Group capability and physical-device behavior are not considered verified until this check and `./Scripts/verify.sh` pass on a Mac with Xcode.

## Claims intentionally not made

- App Store availability or approval
- independent security certification
- fully offline Apple Speech recognition
- autonomous message sending
- language-model intelligence in MAYA
