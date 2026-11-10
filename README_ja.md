# MacTranslate

Apple の Translation と Foundation Models フレームワークを使う、シンプルな macOS 翻訳ユーティリティです。

ほかのアプリでテキストを選択し、**Command+C を2回**押すと、MacTranslate がクリップボードのテキストを翻訳して半透明のフローティングパネルに表示します。

- 入力言語を自動判定し、日本語は英語、それ以外は日本語を既定の翻訳先に設定
- Foundation Models が対応する言語を選択可能（日本語・英語を先頭に表示）
- 言語ペアの右にあるスライダーから Translation LowLatency、Translation、Foundation Models Streaming を選択可能。候補は Mac と言語ペアの対応状況に応じて変わります
- 翻訳方式の選択を保存し、Foundation Models Streaming では生成途中の訳文を表示
- 矢印ボタンで表示中の訳文を入力言語へ逆翻訳
- 翻訳文を選択し、通常の ⌘C でコピー
- SwiftUI の Liquid Glass パネル。Escape キーで閉じる
- Apple の Translation または Foundation Models を使ってデバイス上で翻訳
- API キーやサーバーは不要
- Swift Package Manager でビルド（Xcode プロジェクトは不要）
- 公開 GitHub Releases から Sparkle でアップデートを確認

## 動作要件

- macOS 26 以降
- Swift 6.2 以降 / Apple Command Line Tools がインストールされていること

Foundation Models Streaming の利用には、Apple Intelligence に対応する Mac、Apple Intelligence の有効化、対応言語、モデルアセットの準備が必要です。Translation の候補は選択した言語ペアへの対応状況に応じて表示されます。言語パックが必要な場合は macOS がダウンロード確認を表示します。
macOS 26.4 以降では LowLatency と高品質 Translation を別々に選べます。それ以前の macOS 26 では、対応する言語ペアに Translation の既定方式を使います。

## CLI からビルドして実行する

### 推奨: 小さな .app バンドルを作成する

.build/... にある一時的な実行ファイルを繰り返し実行するよりも、この方法がおすすめです。安定したアプリバンドルを使うと、macOS のアクセシビリティ権限を管理しやすくなります。

~~~bash
git clone <このリポジトリ>
cd MacTranslate
make app
open dist/MacTranslate.app
~~~

初回起動時に、macOS がアクセシビリティへのアクセスを求める場合があります。必要に応じて、次の設定を開いてください。

**システム設定 → プライバシーとセキュリティ → アクセシビリティ**

MacTranslate を有効にしてから、アプリを再起動します。

### 開発モード

次のコマンドで直接実行することもできます。

~~~bash
swift run MacTranslate
~~~

グローバルなキー入力を監視する際、macOS がアクセシビリティ権限をターミナルまたは一時的な実行ファイルに割り当てることがあります。より安定して動作させるには、上記の .app を使う方法がおすすめです。

## 使い方

1. MacTranslate を起動します。
2. Safari、プレビュー、VS Code、PDF リーダーなどでテキストを選択します。
3. 約550ミリ秒以内に ⌘C を2回押します。
4. フローティング翻訳パネルが表示されるまで待ちます。
5. 言語メニューから翻訳先を選ぶか、矢印ボタンで表示中の訳文を入力言語へ逆翻訳します。言語の右のスライダーで翻訳方式も選べます。スライダーにはその言語ペアで利用できる方式だけが表示され、選択は保存されます。Foundation Models Streaming では生成途中の訳文も表示します。
6. 翻訳文を選択して ⌘C でコピーします。Escape キーでパネルを閉じます。

最初の通常の ⌘C ですでに、選択したテキストがシステムのペーストボードにコピーされます。MacTranslate はグローバルキーイベントを監視したあと、NSPasteboard.general からテキストを読み取るだけです。キーボードイベントの送信や抑制は行いません。

### 画面上の文字を翻訳する

**Hyper＋T**（**Control + Option + Shift + Command + T**）を押し、文字をドラッグで囲みます。メニューバーの **Translate Screen Region…** からも開始できます。Escで選択をキャンセルできます。

初回は **システム設定 → プライバシーとセキュリティ → 画面とシステムオーディオ収録** でMacTranslateを許可してから、もう一度お試しください。ドラッグを始めたディスプレイ内で範囲を選べます。Apple Visionがデバイス上で文字を認識し、既存の翻訳パネルが選択中の翻訳方式で翻訳します。

## アップデート

Sparkle 対応版をインストールすると、MacTranslate は Sparkle のスケジュールに従ってアップデートを自動確認します（既定で有効）。メニューバーの MacTranslate メニューから **Check for Updates…** を選ぶと、手動でも確認できます。同じメニューの **Automatically Check for Updates** で自動確認のオン・オフを切り替えられます。ダウンロードとインストールは Sparkle の画面で承認してから行われます。

最初の MVP には Sparkle が含まれていません。既存ユーザーは Sparkle 対応版を一度手動でインストールしてください。その後のリリースはアプリ内で更新できます。

メンテナー用スクリプトで作成するリリース版は Apple Development 証明書で署名し、公証していません。初回ダウンロード時に Gatekeeper が警告を表示した場合は、**システム設定 → プライバシーとセキュリティ** から MacTranslate の起動を許可してください。

## アーキテクチャ

~~~text
ほかのアプリ
  │
  ├─ ユーザーがテキストを選択してコピー
  └─ ⌘C を2回
       │
       ▼
NSEvent のグローバルモニター → NSPasteboard.general
       │
       ▼
SystemLanguageModel.default → 対応言語一覧 → LanguageModelSession.streamResponse
Translation.LanguageAvailability → TranslationSession (.lowLatency / .highFidelity)
        │
        ▼
フローティング NSPanel 内の SwiftUI Liquid Glass ビュー

SwiftUI MenuBarExtra → Sparkle updater → 公開 GitHub appcast とリリース ZIP
~~~

## 現在の MVP における制限

- 入力言語の自動判定は NaturalLanguage を使います。短文や複数言語が混ざった文章では誤判定することがあります。
- 翻訳先の候補は、その Mac のオンデバイス Foundation Model が対応する言語によって異なります。翻訳方式は入力・出力言語の組み合わせごとに確認します。
- ⌘C を550ミリ秒以内に2回押し、2つのグローバルなキー押下イベントとして認識される必要があります。
- Translation の言語パックが必要な場合があります。HighFidelity は実行時に内部フォールバックすることがありますが、フレームワークからアプリへ通知されません。
- Foundation Models は翻訳のみを行うよう指示しても、意図せず言い換えることがあります。
ログイン時の自動起動は初回起動時に選択できます。後から変更するには、メニューバーの MacTranslate アイコンをクリックし、「Launch at Login」を切り替えてください。

- 設定画面、ショートカットの変更、翻訳履歴には、まだ対応していません。

## 便利なコマンド

~~~bash
make build                                      # swift build を実行
make run                                        # swift run MacTranslate
make app                                        # リリースビルド + .app バンドル作成 + アドホック署名
make setup-update-signing                       # Sparkle EdDSA 鍵を作成または取得
SIGNING_IDENTITY="Apple Development: Name (TEAMID)" make package-release VERSION=1.0.0
make release VERSION=1.0.0 RELEASE_ARGS=--dry-run
make clean
~~~

## プロジェクト構成

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

## CLI でビルドしたアプリバンドルを使う理由

この実装では Xcode プロジェクトを使いません。SwiftPM で実行ファイルをコンパイルして Sparkle を取得し、Scripts/build-app.sh で Sparkle.framework を .app に組み込み、アプリ全体に署名します。これにより、開発をターミナル中心のまま保ちながら、macOS のプライバシー権限に必要な安定したバンドル ID を利用できます。

## メンテナー向け: GitHub でアップデートを配信する

アップデーターは既定で、公開リポジトリ RAKE-FMS/MacTranslate の Releases を参照します。Scripts/publish-github.sh は新しいリポジトリを公開で作成します。既存リポジトリの公開・非公開設定は変更しません。

1. GitHub CLI をインストールして認証します: brew install gh、gh auth login。
2. リポジトリがまだない場合は、公開リポジトリを作って main を push します。

   ~~~bash
   ./Scripts/publish-github.sh
   ~~~

3. Sparkle の EdDSA 鍵を一度だけ作成します。

   ~~~bash
   make setup-update-signing
   ~~~

   MacTranslate 専用の秘密鍵はログイン Keychain に保存されます。今後 appcast から参照する更新 ZIP の署名に必要なので、安全な場所へバックアップしてください。Info.plist に保存するのは公開鍵だけです。

4. Apple Development の署名 ID を用意し、dist/release-notes-v1.0.0.md にリリースノートを作成してからパッケージします。

   ~~~bash
   SIGNING_IDENTITY="Apple Development: Name (TEAMID)" make package-release VERSION=1.0.0
   ~~~

   dist/releases/v1.0.0/ に EdDSA 署名付きの Sparkle 用 ZIP、手動インストール用 DMG、SHA-256 チェックサム、署名済み ZIP を参照する appcast が作成されます。

5. まず draft Release を作成して確認し、内容を確認してから明示的に公開します。

   ~~~bash
   make release VERSION=1.0.0
   make release VERSION=1.0.0 RELEASE_ARGS=--publish
   ~~~

   RELEASE_ARGS=--dry-run を指定すると、パッケージを作成して GitHub CLI のコマンドを表示しますが、タグや Release は作成しません。Release 作成前に設定済みリポジトリが公開状態か確認します。別のリポジトリを使う場合は GITHUB_OWNER と GITHUB_REPOSITORY_NAME を一貫して指定してください。
