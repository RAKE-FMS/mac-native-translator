# MacTranslate

A minimal macOS translation utility with Apple's Translation and Foundation Models frameworks.

Select text in another app, press **Command+C twice**, and MacTranslate translates the clipboard text in a translucent floating panel.

- Automatically detects the input language; Japanese defaults to English and other languages default to Japanese
- Choose a target from the languages supported by Foundation Models, with Japanese and English first
- Select Translation LowLatency, Translation, or Foundation Models Streaming from the slider beside the language pair; available choices depend on the device and language pair
- Remembers the selected translation mode and streams partial results when using Foundation Models
- Reverse-translate the displayed result with the swap button
- Select and copy translated text directly with the standard ⌘C shortcut
- SwiftUI Liquid Glass panel; press Escape to dismiss it
- Runs translation on-device through Apple's Translation or Foundation Models framework
- No API key or server required
- Built with Swift Package Manager; no Xcode project is required
- Sparkle checks for updates from public GitHub Releases

## Requirements

- macOS 26 or later
- Swift 6.2+ / Apple Command Line Tools installed

Foundation Models Streaming requires Apple Intelligence, an eligible device, supported languages, and ready model assets. Translation modes are shown when Apple's Translation framework supports the selected language pair; selecting a downloadable language pair lets macOS request the language pack.
macOS 26.4 or later exposes separate LowLatency and high-fidelity Translation strategies. Earlier macOS 26 releases use the framework's default Translation strategy when that language pair is supported.

## Build and run from the CLI

### Recommended: build a small .app bundle

This is preferable to repeatedly running the transient .build/... executable because macOS Accessibility permission is easier to manage for a stable app bundle.

~~~bash
git clone <this repository>
cd MacTranslate
make app
open dist/MacTranslate.app
~~~

On first launch, macOS should prompt for Accessibility access. If necessary, open:

**System Settings → Privacy & Security → Accessibility**

and enable MacTranslate, then relaunch it.

### Development mode

You can also run directly:

~~~bash
swift run MacTranslate
~~~

For global key monitoring, macOS may attribute Accessibility permission to your terminal or the transient executable. The .app route above is more predictable.

## Usage

1. Launch MacTranslate.
2. Select text in Safari, Preview, VS Code, a PDF reader, etc.
3. Press ⌘C twice within about 550 ms.
4. Wait for the floating translation panel.
5. Choose a different target language from the language menu, use the arrow button to translate the displayed result back into its input language, or move the slider beside the languages to choose a translation mode. The slider shows only modes available for that language pair. Your choice is saved; Foundation Models Streaming displays partial output while it generates.
6. Select the translated text and press ⌘C to copy it. Press Escape to dismiss the panel.

The first normal ⌘C already places the selection on the system pasteboard. MacTranslate only observes the global key event and then reads NSPasteboard.general; it does not inject or suppress keyboard events.

## Updates

After installing a Sparkle-enabled release, MacTranslate checks for updates automatically on Sparkle's schedule (enabled by default). Select **Check for Updates…** from the MacTranslate menu-bar item to check manually. Use **Automatically Check for Updates** in that menu to turn background checks on or off. Sparkle asks before downloading and installing an update.

The original MVP did not include Sparkle. Its users must install the first Sparkle-enabled release manually; later releases can be installed from the update window.

Release packages created by the maintainer scripts are signed with an Apple Development identity and are not notarized. On first download, Gatekeeper may require you to approve opening MacTranslate in **System Settings → Privacy & Security**.

## Architecture

~~~text
Other app
  │
  ├─ user selects text and copies it
  └─ ⌘C twice
       │
       ▼
NSEvent global monitor → NSPasteboard.general
       │
       ▼
SystemLanguageModel.default → supported language list → LanguageModelSession.streamResponse
Translation.LanguageAvailability → TranslationSession (.lowLatency / .highFidelity)
        │
        ▼
SwiftUI Liquid Glass view in a floating NSPanel

SwiftUI MenuBarExtra → Sparkle updater → public GitHub appcast and release ZIP
~~~

## Current MVP limitations

- Source-language detection uses NaturalLanguage and can be inaccurate for very short or mixed-language snippets.
- Available target languages depend on the languages exposed by the on-device Foundation Model on that Mac. Translation modes are checked separately for each source and target language pair.
- Translation framework language packs may need to be downloaded. macOS presents its download confirmation when required. HighFidelity may internally fall back to another strategy at runtime; the framework does not report that fallback to the app.
- ⌘C, ⌘C must be received as two global key-down events within 550 ms.
- Foundation Models may occasionally paraphrase despite the translation-only prompt.
You can choose whether to launch at login on first launch. To change it later, click the MacTranslate menu bar icon and toggle “Launch at Login”.

- There is no preferences window, configurable shortcut, or translation history.

## Useful commands

~~~bash
make build                                      # swift build
make run                                        # swift run MacTranslate
make app                                        # release build + .app bundle + ad-hoc signature
make setup-update-signing                       # create/retrieve Sparkle EdDSA key
SIGNING_IDENTITY="Apple Development: Name (TEAMID)" make package-release VERSION=1.0.0
make release VERSION=1.0.0 RELEASE_ARGS=--dry-run
make clean
~~~

## Project layout

~~~text
.
├── Package.swift
├── Package.resolved
├── Info.plist
├── Makefile
├── README.md
├── README_ja.md
├── Scripts/
│   ├── build-app.sh
│   ├── package-release.sh
│   ├── publish-github.sh
│   ├── release-config.sh
│   ├── release.sh
│   └── setup-update-signing.sh
├── Sources/
│   └── MacTranslate/
│       ├── AppUpdater.swift
│       ├── FoundationTranslator.swift
│       ├── MacTranslateApp.swift
│       ├── MacTranslate.swift
│       ├── TranslationLanguageCatalog.swift
│       ├── TranslationMode.swift
│       ├── TranslationModeSlider.swift
│       ├── TranslationPanelController.swift
│       ├── TranslationPanelModel.swift
│       └── TranslationPanelView.swift
└── Tests/
    └── MacTranslateTests/
        └── TranslationLanguageCatalogTests.swift
~~~

## Why a CLI-built app bundle?

The implementation deliberately avoids an Xcode project. SwiftPM compiles the executable and supplies Sparkle; Scripts/build-app.sh embeds Sparkle.framework in the .app and signs the bundle. This gives the utility a stable bundle identity for macOS privacy permissions while keeping the development workflow terminal-first.

## Maintainer: publish updates on GitHub

The updater uses the public RAKE-FMS/MacTranslate Releases feed by default. Scripts/publish-github.sh creates a public repository for a new project; it does not change the visibility of an existing repository.

1. Install and authenticate GitHub CLI: brew install gh and gh auth login.
2. Create the public repository and push main if it does not exist:

   ~~~bash
   ./Scripts/publish-github.sh
   ~~~

3. Create the Sparkle EdDSA key once:

   ~~~bash
   make setup-update-signing
   ~~~

   The MacTranslate private key stays in your login Keychain. Back it up securely; it is needed to sign every future update ZIP referenced by the appcast. Info.plist contains only the public key.

4. Make sure an Apple Development signing identity is available, then create release notes at dist/release-notes-v1.0.0.md and package the release:

   ~~~bash
   SIGNING_IDENTITY="Apple Development: Name (TEAMID)" make package-release VERSION=1.0.0
   ~~~

   This creates a Sparkle ZIP with an EdDSA signature, a DMG for manual installation, SHA-256 checksums, and an appcast that references the signed ZIP under dist/releases/v1.0.0/.

5. Create a draft release for review, then publish it explicitly after checking the assets and notes:

   ~~~bash
   make release VERSION=1.0.0
   make release VERSION=1.0.0 RELEASE_ARGS=--publish
   ~~~

   Add RELEASE_ARGS=--dry-run to package the release and print the GitHub CLI command without creating a tag or release. Release creation checks that the configured repository is public. Set GITHUB_OWNER and GITHUB_REPOSITORY_NAME consistently when using a different repository.
