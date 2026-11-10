# 翻訳遅延の調査（2026-10-07）

モデルロードのタイミングは初回の待ちに関係する。さらに、Translation の設定を作り直すことで翻訳タスクが再実行されず、待機表示が続く不具合を診断パネルで再現した。長文では、ロード後も翻訳方式ごとの生成時間に大きな差がある。

この調査では本番ソースを変更していない。設定の保持による改善は診断用コピーだけで検証した。

## 条件と計測方法

- Apple M5、メモリ16GiB、macOS 27.0（26A428）。Swift 6.3.1。診断プログラムは最適化してビルド。
- 調査時の保存済みモードは `foundationModelsStreaming`。
- 英語→日本語、43文字の短文と589文字の英文。固定の無害なテスト文を使用。
- 言語パックは lowLatency / highFidelity とも `.installed`、Foundation Models は `.available`。
- 各条件3回。時間は `ContinuousClock`、表は中央値と最小〜最大。3回では信頼できるp95を算出できないため記載しない。
- Translation のAPI単体試験は `TranslationSession(installedSource:target:preferredStrategy:)` を使用。ダウンロード確認を含まず、SwiftUIのタスク起動待ちも含まない。
- Foundation Models は本番と同じ指示文・翻訳プロンプトで、新しいセッションを毎回作成。出力は既定のサンプリングのため内容・長さが試行間で多少異なる。
- UI試験は本番の Model / View / Controller / Slider をコンパイルした診断用パネル。実際のホットキー・ペーストボード経路は含まない。完了状態は約5ms間隔で観測。
- OSのモデルを強制アンロードしたり再起動したりしていない。「最初の試行」は完全なコールドスタートを保証しない。既存アプリやOSのモデル使用、バックグラウンド実行、実行順の影響も残る。
- Obsidian works 内を検索したが、本プロジェクト固有の関連ノートは見つからなかった。

## 1. Translation の再実行が抜ける問題：再現・原因確認済み

該当箇所：`Sources/MacTranslate/TranslationPanelModel.swift:41` の `prepareTranslation()` と同ファイルの `configureTranslationTask()`（246行以降）、`TranslationPanelView.swift` の `.translationTask()`。

1. `prepareTranslation()` が毎回 `translationConfiguration = nil` にする。
2. 対応状況を確認した後、同じ言語ペア・方式で新しい Configuration を作る。
3. 新規 Configuration の `version` は0。同じ値で作り直したConfigurationは以前のものと `==` になることをSwiftの実行で確認した。
4. `nil` の中間状態がSwiftUIに描画される前に同値の設定へ戻ると、タスクを起動する変更として認識されない、という説明が実験結果と一致する。
5. `isTranslating` はすでに true なので、タスクのコールバックが来なければ待機表示が続く。本番にはこの状態のタイムアウトがない。

比較実験では `prepareTranslation()` の `translationConfiguration = nil` だけを診断用コピーから削除した。既存の設定更新処理が `invalidate()` を呼ぶようになる。純粋なConfigurationの比較試験も以下の結果だった。

```text
recreated_equal=true  previous_version=0  recreated_version=0
invalidated_equal=false  invalidated_version=1
```

同じ43文字を同じ言語ペアで連続翻訳した結果：

| 方式 | 本番ソースの2・3回目 | 設定保持の診断用コピーの2・3回目 |
| --- | --- | --- |
| LowLatency | 両方とも3秒で観測打ち切り、結果なし | 44.75ms / 42.98ms、両方完了 |
| 高品質 Translation | 358.82msで完了 / 3秒で観測打ち切り | 345.92ms / 343.21ms、両方完了 |
| Foundation Models | 534.55ms / 541.48ms、両方完了 | 570.16ms / 550.38ms、両方完了 |

未完了の試行では `.translationTask` に入るログも出なかった。最初の診断では30秒待つ試行でも未完了を観測した。3秒という数字は翻訳に要した時間ではなく、診断側の打ち切り時間。

Foundation Models は独立した `Task` で開始するので、この設定比較の問題の影響を受けない。成功した高品質の試行もあり、再現するかはSwiftUIの更新タイミングに依存する。

追加確認では文章末尾の番号を毎回変え、各要求の前に0.5秒の間隔を置いた。LowLatencyの2・3回目は現状では両方未完了、設定保持のコピーでは両方完了した。同一文章のキャッシュや極端に速い連打だけが原因という説明は、この結果では支持されない。

同じ言語ペアの新しい内容を訳す際は設定を保持して `invalidate()` する方法がAppleの推奨にも一致する。[Configuration の公式説明](https://developer.apple.com/documentation/translation/translationsession/configuration)

## 2. モデルロードを翻訳要求まで開始しない：コード・実行ログで確認

`FoundationTranslator.swift:6` の `SystemLanguageModel.default` はモデルへの参照であり、この変数を作っただけで翻訳要求に必要なリソースがロード済みになるわけではない。

`FoundationTranslator.swift:37` で翻訳ごとに新しい `LanguageModelSession` を作り、44行の `streamResponse()` へ直ちに進む。起動時・パネル表示時・入力開始時の `prewarm()` はない。固定の指示文も新しいセッションの最初の要求で処理される。

既存MacTranslateの実行に対応するモデル管理ログから、以下を確認した（JST）。

| 時刻 | 観測 |
| --- | --- |
| 01:48:24.844 | 安全性チェック用300Mモデルのロード開始 |
| 01:48:25.256 | 関連する300Mモデルのロード完了記録 |
| 01:48:25.729 | 3Bモデルと汎用アダプタのロード開始 |
| 01:48:26.556 | 汎用アダプタのロード完了 |
| 01:48:28.066〜28.688 | 翻訳用アダプタのロード開始・完了 |
| 01:48:31.504以降 | 安全性チェック用モデルなどのアンロード |
| 01:48:32.760 | 汎用アダプタのアンロード |
| 01:48:33以降 | 安全性チェック用モデルなどの再ロード |

初回に複数モデルが必要になり、OSが途中で解放・再ロードすることは確認できた。ただし、この時間帯には複数の翻訳・方式切替があり、表の全区間を一つの翻訳のロード時間として足し合わせることはできない。アンロードを引き起こした正確な理由や、ユーザーが感じた各遅延との一対一対応は未確定。

セッション作成そのものは軽い。最初の小規模試験では、モデル参照取得10.55ms、対応言語取得1.85ms、セッション作成0.02〜0.53ms、最初の出力423〜523ms、全体500〜596msだった。遅延の中心は `LanguageModelSession` のSwiftオブジェクトを作る処理ではなく、その後のOSサービス・入力処理・推論・安全性チェックにある。

## 3. ロード後も生成時間が大きい：方式比較

API呼び出しから全文取得まで。各行3回。UI表示、80msのクリップボード待機、対応状況確認は除く。

| 方式・セッション | 短文：中央値（範囲） | 長文：中央値（範囲） |
| --- | --- | --- |
| LowLatency・毎回新規 | 21ms（21〜195） | 198ms（195〜1320） |
| LowLatency・保持 | 20ms（20〜20） | 187ms（186〜196） |
| 高品質 Translation・毎回新規 | 337ms（325〜1292） | 2227ms（2203〜2998） |
| 高品質 Translation・保持 | 316ms（314〜320） | 2330ms（2188〜3598） |
| Foundation Models・事前準備なし | 532ms（527〜1794） | 4850ms（4365〜12081） |

最初の短文はLowLatency 195ms、高品質1292ms、Foundation Models 1794msで、後続より遅かった。一方で長文はウォームな試行でも高品質が約2.2秒、Foundation Modelsが数秒かかる。モデルロードを前倒ししても、全文生成時間までは消えない。

Translation の新規セッションと保持セッションの差は、ウォームな短文では小さい。保持するだけでモデルロードの問題がすべて解決するとは言えない。高品質の長文では保持側の遅い試行もあった。

HighFidelityはApple Intelligenceを使う高品質の方式で、LowLatencyとは処理の性質が異なる。[HighFidelity](https://developer.apple.com/documentation/translation/translationsession/strategy/highfidelity)

## 4. Foundation Models の prewarm 比較：長文では改善傾向、保証はない

事前準備した試行は `prewarm()` の後に1.5秒の猶予を置き、同じセッションへ翻訳要求した。表の時間にはこの1.5秒を含めない。これは利用者の操作より前に準備できる状況を模した試験であり、翻訳ボタンを押した後に1.5秒待つ実装の効果ではない。

| 準備方法 | 短文：最初の出力 / 全文の中央値 | 長文：最初の出力 / 全文の中央値 |
| --- | --- | --- |
| なし | 459ms / 532ms | 1426ms / 4850ms |
| prewarmのみ | 548ms / 554ms | 598ms / 3409ms |
| 固定プロンプト先頭付きprewarm | 573ms / 650ms | 491ms / 4712ms |

長文で `prewarm()` の最初の出力は中央値で約0.83秒早かった。一方、短文では改善を確認できず、プロンプト先頭付きでも長文の最初の出力に3943msかかる試行があった。試行数・固定順序・生成内容の差・OS負荷があり、安定した改善率は未確定。

Appleの仕様でも、事前ロードには少なくとも約1秒の猶予が必要で、バックグラウンドやシステム負荷によって即時ロードは保証されない。このアプリはメニューバー常駐なので、その制約も関係する。[prewarm の公式説明](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:))

## 5. 小さい待ち時間と、効果を誤解しやすい箇所

| 処理 | 観測・コード上の事実 | 評価 |
| --- | --- | --- |
| 二度目のコピー後の待機 | `MacTranslate.swift:49`、固定80ms | 毎回乗るが、数秒の主因ではない |
| 入力言語検出 | 初回13〜23ms、後続約0.6〜1.2ms | 小さい |
| 方式対応状況確認 | 初回low 10.4ms + high 11.2ms、後続合計約13ms | 直列・毎回実行だが、この環境では小さい |
| 初回パネル初期化 | Model約4〜27ms、Panel約29〜107ms | 初回の上乗せ。`AppDelegate` のlazyプロパティ |
| 言語パックの取得 | 今回の英日ペアは両方式ともinstalled | 今回はダウンロード待ちではない |
| 翻訳結果表示 | Translationは全文が返るまで表示せず、Foundation Modelsのみ途中表示 | 同じ全文所要時間でも体感が異なる |

`TranslationPanelModel.prepareTranslation()` はアプリ独自の入力・状態準備であり、Appleの `TranslationSession.prepareTranslation()` を呼んでいない。また、Appleの同名メソッドは言語パック取得を事前に許可するためのAPIで、Foundation Modelsの `prewarm()` と同等のメモリロード保証ではない。[prepareTranslation の公式説明](https://developer.apple.com/documentation/translation/translationsession/preparetranslation())

## 改善の優先順位

1. **Translationの再実行漏れを修正する。** 入力更新時に設定を保持し、既存の `invalidate()` を通す。診断用コピーでは効果を確認済み。本番で同じ言語ペア・異なるテキスト・パネル再表示・連続要求・方式変更の回帰確認が必要。
2. **Foundation Modelsの翻訳用セッションを要求前に準備する。** 使うセッション自身を保持してprewarmし、そのセッションを次の翻訳に渡す設計にする。使用後は別の空セッションを準備すれば翻訳履歴の混入・コンテキスト増大を避けられる。ただし常時ロードや改善率は保証できないので計測が必要。
3. **利用者が選んだ方式と生成中の状態を分かりやすくする。** 低遅延が必要な場面のLowLatencyと、長文で秒単位かかる生成方式を区別できる表示にする。現在も方式は保存されており、調査時にはFoundation Modelsが選ばれていた。
4. **必要なら対応状況確認を並行化・短期キャッシュする。** 得られる改善は今回の環境では十数ms規模。優先度は上記より低い。利用可能状態の変化を反映する必要がある。

初回ロード・タスク未開始・最初の出力・全文生成は別々に計測すべき。実運用での個別の遅い要求を確定するには、要求IDを付けて「ホットキー認識、対応状況確認終了、translationTask開始、最初の出力、完了」を記録し、必要に応じてFoundation ModelsのInstrumentsでアセットロード時間を重ねる。[Appleのキャッシュ・計測説明](https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions)
