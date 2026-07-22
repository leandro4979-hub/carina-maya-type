# Verification

## Automated checks

`./Scripts/verify.sh` performs:

1. privacy-invariant checks for both keyboard extensions;
2. an unsigned CARINA simulator build;
3. an unsigned MAYA simulator build.

GitHub Actions runs the same script on pushes and pull requests.

## Development evidence

Before the initial public release, both apps compiled for an iOS Simulator and a connected physical iPhone, and both application bundles launched on that device. This is development verification, not App Store review or certification.

## Claims intentionally not made

- App Store availability or approval
- independent security certification
- fully offline Apple Speech recognition
- autonomous message sending
- language-model intelligence in MAYA
