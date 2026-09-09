# MouseExtension_Win11

## 概要

MouseExtension_Win11 は、Windows 11 のマウス操作を拡張する MouseGestureL.ahk 1.41 用プラグインです。ウィンドウの最前面化、タブやエクスプローラー表示のホイール操作、タスクバー操作、音量操作、スクロール補助などを追加します。

## 動作環境

- Windows 11
- MouseGestureL.ahk 1.41
- AutoHotkey v1.1.37.02 Unicode 64-bit
- AutoHotkey v2 には対応していません

## 配布ファイル

- `MouseExtension_Win11.ahk` — プラグイン本体
- `MouseExtensionNative.dll` — TaskButton 系の対象解決などに使う必須の Native Helper
- `README.md` — 導入時の案内
- `MANUAL.md` — 詳細ユーザーマニュアル
- `LICENSE` — MouseExtension_Win11 の MIT License

`MouseExtension_Win11.ini` は原則として配布しません。初回読み込み時に `MouseExtension_Win11.ahk` と同じフォルダーへ自動生成されます。

## インストール

1. [MouseGestureL.ahk 作者公式の Ver. 1.41／ダウンロード案内](https://ss1.xrea.com/pyonkichi.g1.xrea.com/mglahk.html)から MouseGestureL 1.41 を用意します。
   - 通常の `Setup.vbs` 方式では、同梱の AutoHotkey v1.1.37.02 を利用するため、AutoHotkey の別途インストールは不要です。
   - 既存の AutoHotkey 環境から利用する場合は、AutoHotkey v1.1.37.02 Unicode 64-bit を使用してください。AutoHotkey v2 では動作しません。
2. 標準構成では、次の2ファイルを MouseGestureL の `Plugins` フォルダーへ配置します。`MouseExtensionNative.dll` のファイル名は変更しないでください。

   ```text
   MouseGestureL のフォルダー
   └─ Plugins
      ├─ MouseExtension_Win11.ahk
      └─ MouseExtensionNative.dll
   ```

   標準構成以外では、MouseGestureL がプラグインを読み込むフォルダーへ、この2ファイルを配置します。README、MANUAL、LICENSEを `Plugins` へ置く必要はありません。
3. `MouseExtension_Win11.ahk` は単体実行せず、MouseGestureL からプラグインとして読み込みます。
   - `Setup.vbs` 方式で導入した場合は、`MouseGestureL.exe` を起動します。
   - 既存の AutoHotkey 環境を使用する場合は、通常どおり `MouseGestureL.ahk` を起動します。
4. MouseGestureL がすでに起動中なら、MouseGestureL またはプラグインを再読み込みするか、MouseGestureL を再起動します。
5. 正常に初回読み込みされると、`MouseExtension_Win11.ini` が `MouseExtension_Win11.ahk` と同じフォルダーへ自動生成されます。

具体的な絶対パスは MouseGestureL の設置方法によって異なります。

## 主な機能

- **AlwaysOnTop** — タイトルバーを Shift+左クリックして最前面表示を切り替えます。
- **OpenExeFolder** — タイトルバーを Ctrl+左クリックして、実行ファイルの場所を開き選択します。
- **MoveDisabledWindow** — 無効化されたウィンドウのタイトルバーを左ドラッグして移動します。
- **TabSwitch** — 対応するタブ領域上のホイールで前後のタブへ切り替えます。
- **ExplorerViewMode** — エクスプローラー上部領域のホイールで表示形式を切り替えます。
- **StartWheel** — スタートボタン上のホイールでウィンドウを一括最小化／復元します。
- **TaskButtonWheel** — タスクバーボタン上のホイールで対象ウィンドウを最小化／復元します。
- **TaskButtonMiddleClick** — タスクバーボタンの中クリックで通常の閉じる操作を送ります。初期状態は OFF です。
- **TrayWheelVolume** — 通知領域上のホイールでマスター音量を変更します。
- **Volume acceleration** — 素早い連続ホイール時に音量変更幅を加速します。
- **TrayMiddleClickMute** — 通知領域の中クリックでマスターミュートを切り替えます。
- **Volume Overlay** — 音量またはミュート状態を画面上に表示します。
- **SpecialScrollbarScroll** — 対応スクロールバー上のホイールを line／page／edge 動作へ変換します。初期状態は ON で、縦・横とも1ページ単位です。
- **AccelScroll** — 通常の縦ホイールを残したまま、速度に応じた追加スクロールを送ります。初期状態は OFF です。

## 基本的な設定方法

`MouseExtension_Win11.ini` をテキストエディターで編集します。多くの機能は `0`（OFF）または `1`（ON）で切り替えます。変更後は MouseGestureL またはプラグインを再読み込みしてください。

全設定、操作方法、有効値、設定例は [MANUAL.md](MANUAL.md) を参照してください。MANUAL.md は人間向けの正式な詳細マニュアルです。必要なら MANUAL.md を ChatGPT などの AI に添付し、設定方法について質問することもできます。

## ライセンス

MouseExtension_Win11 は MIT License で提供されます。詳細は [LICENSE](LICENSE) を参照してください。

MouseGestureL 1.41 本体は MouseExtension_Win11 の配布物には含まれません。MouseGestureL その他の第三者ソフトウェアには、それぞれのライセンス条件が適用されます。

## 主な既知制約

- Windows 11、MouseGestureL 1.41、AutoHotkey v1.1.37.02 Unicode 64-bit を対象とします。
- `MouseExtensionNative.dll` が利用できない場合、Native Helper を必要とする TaskButton 系の対象解決が安全側で中止されることがあります。
- ExplorerViewMode は対象エクスプローラーウィンドウの DPI が96の場合のみ動作し、96以外では安全側で表示を変更しません。
- SpecialScrollbarScroll は Firefox／Chrome／Edge のページ右端スクロールバーには対応していません。カスタム描画スクロールバーも保証外です。
- 管理者権限で動くアプリでは、権限差により AccelScroll の追加分が届かない場合があります。その場合も通常の物理ホイールは残ります。
- 対応条件や詳細な制約は [MANUAL.md](MANUAL.md) を確認してください。
