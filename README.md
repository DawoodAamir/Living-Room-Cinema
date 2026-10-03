# Living Room Cinema

A native tvOS media browser with remote focus navigation, AVKit playback, local favorites, and resumable viewing history.

## Run

Open **Living Room Cinema.xcodeproj** with Xcode 27. The app targets tvOS 27 and uses `com.dd.livingroomcinema`. Run on the Apple TV simulator or select your own development team for a physical Apple TV. No signing identity is included.

**Orbit Study** and **Tidal Lines** are original, silent 24-second videos bundled for offline use. Their generators are included. **Apple HLS Example** is explicitly labelled developer test content streamed from Apple’s CDN after you select Play; it is not a movie catalog or a bundled third-party download.

## Browse and play

Search titles, filter favorites, open a title, and choose Play from start or Resume. The native AVKit player supplies seeking, playback controls, audio selection, and subtitles when the selected media provides them. The bundled studies have no audio or subtitle tracks; Apple’s HLS example includes renditions for testing.

Viewing position is saved every five seconds and on player dismissal. Titles within three seconds of the end restart from the beginning. Clear viewing history preserves favorites. Nothing autoplays while browsing, and the app requires no account.

Semantic SwiftUI fonts follow tvOS 27 text sizing. Adaptive cards, focus sections, and system button styles support remote navigation. Layered app icons and top-shelf artwork are original and reproducible.

## Engineering

Swift 6 complete concurrency, main-actor UI and playback ownership, actor-isolated atomic storage, serialized library updates, cancellable asset loading, stale-result guards, bounded decoding, and explicit missing-media/network error states. No third-party dependencies or tracking SDKs.

```sh
swift test
swift test -c release
bash Scripts/test-ui.sh
```

The simulator tests use bundled media. Network availability, codecs, subtitle/audio selection, AirPlay, physical remote behavior, and interruption handling require device checks. This is a portfolio playback app without DRM, purchases, live channels, user-uploaded media, or a commercial content license.

See [verification](Docs/Verification.md), [privacy](PRIVACY.md), and [contributing](CONTRIBUTING.md). Code and original media are MIT licensed. Apple’s remote example remains subject to its source terms: [HLS examples](https://developer.apple.com/streaming/examples/).
