# MacTranslate

Apple のオンデバイス Foundation Models フレームワークを使った、シンプルな macOS 翻訳ユーティリティです。

ほかのアプリでテキストを選択し、**Command+C を2回**押すと、MacTranslate がクリップボードのテキストを翻訳して小さなフローティングパネルに表示します。

- 日本語のテキスト → 英語
- 日本語以外のテキスト → 日本語
- FoundationModels を使ってデバイス上で翻訳
- API キーやサーバーは不要
- Swift Package Manager でビルド（Xcode プロジェクトは不要）
- 公開 GitHub Releases から Sparkle でアップデートを確認

## 動作要件

- macOS 26 以降
- Apple Intelligence に対応した Mac
- Apple Intelligence が有効で、モデルアセットの準備が完了していること
- Swift 6.2 以降 / Apple Command Line Tools がインストールされていること

Foundation Models フレームワークは Apple のオンデバイスモデルを使用します。そのため、モデルを利用できるかどうかは、デバイスの対応状況、Apple Intelligence の設定、言語と地域のサポート、モデルのダウンロード状況によって異なります。

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
5. **コピー**を使って翻訳結果をコピーします。

最初の通常の ⌘C ですでに、選択したテキストがシステムのペーストボードにコピーされます。MacTranslate はグローバルキーイベントを監視したあと、NSPasteboard.general からテキストを読み取るだけです。キーボードイベントの送信や抑制は行いません。

## アップデート

Sparkle 対応版をインストールすると、MacTranslate は Sparkle のスケジュールに従ってアップデートを自動確認します（既定で有効）。メニューバーの MT メニューから **Check for Updates…** を選ぶと、手動でも確認できます。同じメニューの **Automatically Check for Updates** で自動確認のオン・オフを切り替えられます。ダウンロードとインストールは Sparkle の画面で承認してから行われます。

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
SystemLanguageModel.default → LanguageModelSession
       │
       ▼
フローティング NSPanel

メニューバーの MT → Sparkle updater → 公開 GitHub appcast とリリース ZIP
~~~

## 現在の MVP における制限

- 言語の判定ルールは意図的にシンプルにしています。入力に日本語の文字が含まれていれば英語に、それ以外は日本語に翻訳します。
- ⌘C を550ミリ秒以内に2回押し、2つのグローバルなキー押下イベントとして認識される必要があります。
- この MVP は Foundation Models の利用を目的としているため、Apple の専用 Translation フレームワークではなく LLM による翻訳を使います。
- 翻訳のみを行うようプロンプトで指定していますが、Foundation Models が意図せず言い換えることがあります。製品版では翻訳品質を評価し、必要に応じて Translation フレームワークを決定的な既定バックエンドとして追加する方法が考えられます。
- ログイン時の自動起動、設定画面、ショートカットの変更、翻訳履歴、ストリーミング出力には、まだ対応していません。

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
└── Sources/
    └── MacTranslate/
        ├── AppUpdater.swift
        ├── MacTranslate.swift
        └── UpdateStatusItemController.swift
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
