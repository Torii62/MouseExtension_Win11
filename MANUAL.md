# MouseExtension_Win11 v1.1.1 Manual

## 1. はじめに

MouseExtension_Win11 は、Windows 11 上のマウス操作を拡張する MouseGestureL.ahk 1.41 用プラグインです。タイトルバー、タブ、エクスプローラー、タスクバー、通知領域、スクロールバーなど、カーソル位置に応じた操作を追加します。

本マニュアルは v1.1.1 の正式なユーザーマニュアルです。記載内容は、v1.1.1 版 `MouseExtension_Win11.ahk` の設定スキーマと実装、および明示された Windows 11 実機確認結果に基づきます。

## 2. このマニュアルの使い方

導入だけを確認したい場合は「4. インストール」、操作を知りたい場合は「7. 機能別マニュアル」、設定可能な値を調べたい場合は「8. INI設定リファレンス」を参照してください。問題が起きた場合は「11. トラブルシューティング」と「12. FAQ」を確認してください。

### AIに質問する場合

この `MANUAL.md` を ChatGPT などの AI に添付し、例えば次のように質問できます。

- Firefox だけ AccelScroll を無効にしたい
- TaskButtonWheel の MultiWindow を有効にしたい
- SpecialScrollbarScroll の `-1` と `-2` の違いを知りたい
- 音量の変更幅を変えたい

AIの回答を適用する前に、設定名、有効値、対象バージョンが本マニュアルと一致するか確認してください。AutoHotkey v2 用への読み替えはできません。

## 3. 動作環境

- OS: Windows 11
- ホスト: MouseGestureL.ahk 1.41
- AutoHotkey: v1.1.37.02 Unicode 64-bit
- AutoHotkey v2: 非対応

このプラグインは単体で実行するものではなく、MouseGestureL から読み込みます。

## 4. インストール

1. [MouseGestureL.ahk 作者公式の Ver. 1.41／ダウンロード案内](https://ss1.xrea.com/pyonkichi.g1.xrea.com/mglahk.html)から MouseGestureL 1.41 を用意します。
2. 実行環境を確認します。
   - 通常の `Setup.vbs` 方式では、MouseGestureL 1.41 に同梱された AutoHotkey v1.1.37.02 を利用するため、AutoHotkey の別途インストールは不要です。
   - 既存の AutoHotkey 環境から MouseGestureL を利用する場合は、AutoHotkey v1.1.37.02 Unicode 64-bit を使用します。AutoHotkey v2 は非対応です。
3. 標準構成では、次の2ファイルを MouseGestureL の `Plugins` フォルダーへ配置します。`MouseExtensionNative.dll` のファイル名は変更しないでください。

   ```text
   MouseGestureL のフォルダー
   └─ Plugins
      ├─ MouseExtension_Win11.ahk
      └─ MouseExtensionNative.dll
   ```

   標準構成以外では、MouseGestureL がプラグインを読み込むフォルダーへ、この2ファイルを配置します。README、MANUAL、LICENSEを `Plugins` へ置く必要はありません。
4. `MouseExtension_Win11.ahk` は単体実行せず、MouseGestureL からプラグインとして読み込みます。
   - `Setup.vbs` 方式で導入した場合は、`MouseGestureL.exe` を起動します。
   - 既存の AutoHotkey 環境を使用する場合は、通常どおり `MouseGestureL.ahk` を起動します。
5. MouseGestureL がすでに起動中なら、MouseGestureL またはプラグインを再読み込みするか、MouseGestureL を再起動します。
6. 正常に初回読み込みされると、`MouseExtension_Win11.ini` が `MouseExtension_Win11.ahk` と同じフォルダーへ自動生成されます。

MouseGestureL の設置方法は環境ごとに異なるため、本マニュアルでは具体的な絶対パスを指定しません。

## 5. MouseExtensionNative.dll

`MouseExtensionNative.dll` は v1.1.1 の配布必須ファイルです。`MouseExtension_Win11.ahk` と同じフォルダーに置いてください。

起動時に DLL を読み込み、少なくとも次の export を利用します。

- `ME_GetEffectiveWindowAppUserModelId`
- `ME_IsWindowOnCurrentVirtualDesktop`

これらは主に、タスクバーボタンに対応する安全なウィンドウを識別するために使われます。DLL がない、読み込めない、必要な export がない場合、Native Helper は利用不能になります。プラグイン全体が必ず停止するわけではありませんが、Native Helper が必要な TaskButton 系の対象解決は、誤操作を避けるため何もしないことがあります。

## 6. MouseExtension_Win11.ini

### 6.1 生成と補完

- INI がない場合、初回読み込み時に UTF-8 の `MouseExtension_Win11.ini` を自動生成します。
- 固定スキーマの section または key が欠けている場合、次回読み込み時に既定値で補完します。
- `[TabSpecial]` と `[TabIgnore]` が欠けている場合も、説明コメント付きの section を追記します。
- 既に存在する設定値は原則として維持します。
- 現在値が不正でも、その値を INI へ自動で書き戻しません。実行中だけ安全な既定値または safety fallback を使います。
- 設定変更後は MouseGestureL またはプラグインの再読み込みが必要です。

古い INI に v1.0.0 で未使用の key や section が残っていても、自動削除しません。

### 6.2 共通の値の書き方

- ON/OFF 設定は `0` または `1` の1文字だけが有効です。
- 整数設定は10進整数として読みます。負数が許可される設定では先頭の `-` を使用できます。先頭の `+` は使用できません。小数、単位付き文字列、空白以外の余分な文字は無効です。
- 色は `RRGGBB` 形式の6桁16進数です。`#` は付けません。読み込み時は大文字に正規化されます。
- key 名と section 名は正式名のまま使うことを推奨します。

### 6.3 初期INIの全体像

```ini
[EnableFunction]
AlwaysOnTop=1
OpenExeFolder=1
MoveDisabledWindow=1
TabSwitch=1
ExplorerViewMode=1
Taskbar=1
AccelScroll=0
SpecialScrollbarScroll=1
BrowserDragScroll=1

[General]
Debug=0

[AlwaysOnTop]
FrameColor=0078D4
FrameThickness=3

[TabSwitch]
Firefox=1
Chrome=1
Edge=1
Notepad=1
Explorer=1
SysTabControl32=1

[BrowserDragScroll]
Firefox=1
Chrome=1
Edge=1
Explorer=1

[AccelScroll]
MinThrottle=2
MaxThrottle=10
MinWheelSpeed=8
MaxWheelSpeed=25
ExcludeExe=

[Taskbar]
StartWheel=1
TaskButtonWheel=1
TaskButtonWheelMultiWindow=1
TaskButtonMiddleClick=0
TaskButtonMiddleClickMultiWindow=0
TrayWheelVolume=1
TrayMiddleClickMute=1

[Volume]
Step=1
AccelStrength=3

[VolumeOverlay]
Enabled=1
DurationMs=2000
MainColor=444444

[SpecialScrollbarScroll]
Vertical=-1
Horizontal=-1

[TabSpecial]
; Rule1=bosa_sdm_XL9||15|31|851|39

[TabIgnore]
; Rule1=SomeWindowClass|Options
```

`BrowserDragScroll` は現行スキーマに含まれます。`LongPressDoubleClick` は v1.1.1 の INI スキーマにはありません。

## 7. 機能別マニュアル

### 7.1 AlwaysOnTop

ウィンドウを最前面表示に固定し、固定中は色付きの枠を表示します。

操作は、対象ウィンドウのタイトルバーを **Shift+左クリック** です。同じ操作で固定と解除を切り替えます。Ctrl、Alt、Win キーを同時に押している場合は動作しません。

- 全体スイッチ: `[EnableFunction] AlwaysOnTop=1`（既定 ON）
- 枠色: `[AlwaysOnTop] FrameColor=0078D4`
- 枠の太さ: `[AlwaysOnTop] FrameThickness=3`（有効範囲 1～10）

通常のトップレベルウィンドウと、システムがタイトルバーとして認識する領域を対象にします。独自描画のタイトルバーなど、標準のタイトルバー判定ができない UI は保証しません。

### 7.2 OpenExeFolder

対象ウィンドウの実行ファイルがあるフォルダーをエクスプローラーで開き、その実行ファイルを選択します。

操作は、対象ウィンドウのタイトルバーを **Ctrl+左クリック** です。Shift、Alt、Win キーを同時に押している場合は動作しません。左ボタンを離した後にフォルダーを開きます。

- 全体スイッチ: `[EnableFunction] OpenExeFolder=1`（既定 ON）

実行ファイルの完全なパスを安全に取得できるトップレベルウィンドウが対象です。ホストプロセスとの区別が曖昧なウィンドウや、パスを取得できない対象では何もしません。開いたエクスプローラーを前面にする処理は best effort であり、Windows が前面化を拒否する場合があります。

### 7.3 MoveDisabledWindow

無効化されて通常はドラッグできないトップレベルウィンドウを移動します。

操作は、対象のタイトルバーを **修飾キーなしで左ドラッグ** です。Shift、Ctrl、Alt、Win キーを押している場合は動作しません。

- 全体スイッチ: `[EnableFunction] MoveDisabledWindow=1`（既定 ON）

対象は `WS_DISABLED` 状態で、標準のタイトルバー判定が成立する安全なトップレベルウィンドウです。通常の有効なウィンドウや、独自描画のタイトルバーは対象になりません。

### 7.4 TabSwitch

前面ウィンドウの認識済みタブ領域にカーソルを置き、縦ホイールでタブを切り替えます。

- WheelUp: `Ctrl+Shift+Tab` を送信して前のタブへ移動
- WheelDown: `Ctrl+Tab` を送信して次のタブへ移動
- 全体スイッチ: `[EnableFunction] TabSwitch=1`（既定 ON）

物理的に左ボタンを押している間は、ドラッグ中のホイール操作との競合を避けるため TabSwitch を行いません。

標準アダプターは Firefox、Chrome、Edge、Windows 11 のメモ帳、エクスプローラー、`SysTabControl32` です。各 `[TabSwitch]` key で個別に ON/OFF できます。key が ON でも、そのアプリの全バージョンや全 UI を保証するものではありません。カーソル直下が実装の厳密なタブ条件を満たす場合だけ処理します。

独自のタブ領域は `[TabSpecial]`、除外対象は `[TabIgnore]` で指定できます。`TabIgnore` を先に評価し、その後 `TabSpecial`、ブラウザー、エクスプローラー、メモ帳、`SysTabControl32` の順で判定します。

#### TabSpecial

形式は次のとおりです。

```ini
[TabSpecial]
Rule1=Class|Title|Left|Top|Width|Height
```

- `RuleN` の N は 1 以上の整数です。番号の小さい順に評価します。
- `Class` はウィンドウクラス名の大文字小文字を区別しない完全一致です。
- `Title` はウィンドウタイトルの大文字小文字を区別しない部分一致です。
- `Class` または `Title` が空なら、その条件を使いません。両方空は無効です。
- `Left`、`Top`、`Width`、`Height` はウィンドウ基準の矩形を表す整数です。
- `Width` と `Height` は 1 以上です。
- 最初に一致した有効な rule を使用します。

初期 INI に記載されるコメント例:

```ini
Rule1=bosa_sdm_XL9||15|31|851|39
```

#### TabIgnore

形式は次のとおりです。

```ini
[TabIgnore]
Rule1=Class|Title
```

N、`Class`、`Title` の照合規則は TabSpecial と同じです。両方空の rule は無効です。一致した前面ウィンドウでは TabSwitch を行いません。

初期 INI に記載されるコメント例:

```ini
Rule1=SomeWindowClass|Options
```

### 7.5 ExplorerViewMode

前面のエクスプローラー上部の認識済み領域にカーソルを置き、ホイールで表示形式を切り替えます。

- 全体スイッチ: `[EnableFunction] ExplorerViewMode=1`（既定 ON）
- WheelDown: 次の表示プリセットへ進む
- WheelUp: 前の表示プリセットへ戻る

実装上の順序は、特大アイコン、大アイコン、中アイコン、小アイコン、一覧、詳細、並べて表示、コンテンツです。8プリセットは循環し、コンテンツで WheelDown を回すと特大アイコンへ、特大アイコンで WheelUp を回すとコンテンツへ移ります。

Windows 11 エクスプローラーの前面ウィンドウ、認識済み上部領域、現在の Shell View がすべて安全に確認でき、対象エクスプローラーウィンドウの DPI が96の場合だけ動作します。DPI が96以外の場合は fail closed で表示を変更しません。未知の `(ViewMode, IconSize)` を既知プリセットへ補正しません。

### 7.6 StartWheel

スタートボタン上のホイールでウィンドウを一括最小化／復元します。

- WheelDown: `Win+M` によりウィンドウを最小化
- WheelUp: この機能による未復元の WheelDown とのペアがある場合、`Win+Shift+M` により復元
- 設定: `[Taskbar] StartWheel=1`（既定 ON）
- 親スイッチ: `[EnableFunction] Taskbar=1`（既定 ON）

復元後の Z-order は Windows 標準の `Win+Shift+M` の挙動に依存します。

### 7.7 TaskButtonWheel

タスクバーボタン上で対象ウィンドウを最小化、復元、アクティブ化します。

- WheelDown: 対象ウィンドウを最小化
- WheelUp: 最小化中なら復元し、アクティブ化
- 設定: `[Taskbar] TaskButtonWheel=1`（既定 ON）
- 親スイッチ: `[EnableFunction] Taskbar=1`（既定 ON）

`TaskButtonWheelMultiWindow` の意味:

`[Taskbar] TaskButtonWheelMultiWindow=1` が既定です。

| 値 | 動作 |
|---:|---|
| `0` | 複数ウィンドウに対応する曖昧なタスクバーボタンでは操作しません。単一ウィンドウだけを処理します。 |
| `1` | 複数ウィンドウを、下記の選択規則で処理します。 |

単一ウィンドウでは、WheelDown は表示中なら最小化します。WheelUp は最小化中なら復元して同じウィンドウをアクティブ化し、すでに表示中でもそのウィンドウをアクティブ化します。

`TaskButtonWheelMultiWindow=1` の WheelDown は、1回につき表示中ウィンドウを1枚だけ最小化します。対象グループ内のウィンドウが前面ならそのウィンドウを、明確な別グループが前面なら対象グループの front-most visible window を選びます。この機能自身が実際に最小化できた HWND だけを、実行中の一時的な LIFO 履歴へ記録します。

WheelUp は、まず LIFO 履歴の有効な先頭を復元してアクティブ化します。該当履歴がなくても最小化中の候補があれば、front-most minimized window を復元してアクティブ化します。最小化中の候補がなく、対象グループ内のウィンドウが前面なら何もしません。明確な別グループが前面なら、対象グループの front-most visible window をアクティブ化します。表示中ウィンドウを WheelUp で順番に切り替える機能ではありません。

複数ウィンドウ時も、候補集合、AppUserModelID、現在の状態などを確認できない場合は誤操作を避けて何もしません。LIFO は実行中の一時的な履歴であり、プラグイン終了時に消えます。Native Helper が利用不能の場合、対象解決が安全側で中止されることがあります。

### 7.8 TaskButtonMiddleClick

タスクバーボタンを中クリックして、対象ウィンドウへ通常の「閉じる」要求を送ります。強制終了ではありません。

- 設定: `[Taskbar] TaskButtonMiddleClick=0`（既定 OFF）
- 親スイッチ: `[EnableFunction] Taskbar=1`（既定 ON）

単一ウィンドウを一意に解決できた場合は、そのウィンドウを閉じます。複数ウィンドウに対応するボタンでは `TaskButtonMiddleClickMultiWindow` を使います。

| 値 | 複数ウィンドウ時の動作 |
|---:|---|
| `0` | 何もしません。 |
| `1` | Z-order 上で最初の表示中ウィンドウを1つ閉じます。すべて最小化中なら先頭候補を1つ閉じます。 |
| `2` | 検証済み候補すべてへ、Z-order 順に通常の閉じる要求を1回ずつ送ります。 |

候補が曖昧または不整合なら安全側で中止します。閉じる要求にアプリが応じない場合も、再試行や強制終了は行いません。

### 7.9 TrayWheelVolume と Volume acceleration

プライマリタスクバーの認識済み通知領域アイコン上でホイールを回し、既定の再生デバイスのマスター音量を変更します。

- WheelUp: 音量を上げる
- WheelDown: 音量を下げる
- 設定: `[Taskbar] TrayWheelVolume=1`（既定 ON）
- 親スイッチ: `[EnableFunction] Taskbar=1`（既定 ON）
- 1倍時の変更幅: `[Volume] Step=1`（1～10、単位は音量の percentage point）
- 加速強度: `[Volume] AccelStrength=3`（1～5）

同じ方向の連続操作に対する multiplier は次のとおりです。方向が変わった最初の操作は1倍です。

| 前回の成功した同方向操作からの時間 | multiplier |
|---|---:|
| 35 ms 以下 | `AccelStrength` |
| 35 ms 超～110 ms 以下 | `max(1, AccelStrength - 1)` |
| 110 ms 超 | `1` |

実際の変更幅は `Step × multiplier` percentage point で、0～100%に収めます。通知領域全体を座標だけで判定するのではなく、実装が認識する通知アイコンを厳密に判定します。セカンダリタスクバーの通知領域は対象外です。

### 7.10 TrayMiddleClickMute

プライマリタスクバーの認識済み通知領域アイコンを中クリックし、既定の再生デバイスのマスターミュートを切り替えます。

- 設定: `[Taskbar] TrayMiddleClickMute=1`（既定 ON）
- 親スイッチ: `[EnableFunction] Taskbar=1`（既定 ON）

対象領域の判定条件は TrayWheelVolume と同じです。

### 7.11 Volume Overlay

TrayWheelVolume または TrayMiddleClickMute の操作に成功したとき、カーソルに最も近いモニターの作業領域右下へ状態を表示します。

- `[VolumeOverlay] Enabled=1` — 表示の ON/OFF
- `[VolumeOverlay] DurationMs=2000` — 表示時間、250～10000 ms
- `[VolumeOverlay] MainColor=444444` — バー、数値、ミュート記号の色

ミュート中はミュート記号、ミュート解除中は 0～100 の音量値を表示します。オーバーレイは入力を受け取らず、前面を奪いません。

### 7.12 SpecialScrollbarScroll

スクロールバーそのものにカーソルを置いたとき、縦ホイールを指定したスクロール操作へ変換します。

- 全体スイッチ: `[EnableFunction] SpecialScrollbarScroll=1`（既定 ON）
- 縦スクロールバー: `[SpecialScrollbarScroll] Vertical=-1`
- 横スクロールバー: `[SpecialScrollbarScroll] Horizontal=-1`

したがって既定では、縦・横スクロールバーとも page increment／decrement を行います。

Vertical と Horizontal の値:

| 値 | 動作 |
|---:|---|
| `0` | その軸を無効化します。 |
| `1`～`10` | WheelUp は small decrement、WheelDown は small increment を、値の回数だけ行います。 |
| `-1` | WheelUp は page decrement、WheelDown は page increment を1回行います。 |
| `-2` | WheelUp は先頭側、WheelDown は末尾側へ移動します。 |

`1`～`10` は、1回の捕捉 Wheel 入力につき small decrement／increment を指定回数行います。正式対応方式は classic Win32 scrollbar と、厳密な XAML/UIA 条件を満たす scrollbar です。座標だけを使った推測 fallback は行いません。

今回の Windows 11 実機環境での動作確認済み例は、エクスプローラー、メモ帳、システム情報（`msinfo32`）、7-Zip File Manager です。これは各アプリの全画面、全バージョン、全スクロールバーを保証するものではありません。

Firefox、Chrome、Edge のページ右端スクロールバーは、現行実装の厳密な semantic hit-test 条件を満たさないため未対応です。カスタム描画スクロールバーも保証しません。厳密な XAML/UIA Horizontal は、十分に自然な実機対象がなく未実測です。

設定例:

```ini
[EnableFunction]
SpecialScrollbarScroll=1

[SpecialScrollbarScroll]
Vertical=-1
Horizontal=-1
```

### 7.13 BrowserDragScroll

Firefox／Chrome／Edge の対応するお気に入り・ブックマークサイドバーと、Windows 11 エクスプローラー右ペインで、LButton drag 中の WheelDown／WheelUpにより縦スクロールします。ブラウザーではサイドバー項目の並べ替え中、エクスプローラーでは右ペインの selection rectangle drag または実ファイルdrag中が対象です。

- 全体スイッチ: `[EnableFunction] BrowserDragScroll=1`（既定 ON）
- Firefox: `[BrowserDragScroll] Firefox=1`（既定 ON）
- Chrome: `[BrowserDragScroll] Chrome=1`（既定 ON）
- Edge: `[BrowserDragScroll] Edge=1`（既定 ON）
- Windows 11 エクスプローラー右ペイン: `[BrowserDragScroll] Explorer=1`（既定 ON）

全体スイッチと対象ごとのスイッチがともに ON で、対象条件を厳密に満たす場合だけホイール入力を処理します。対象外のUIや判定不能な状態ではホイールを奪いません。ブラウザーやエクスプローラーのすべてのdrag操作、すべてのUIを対象にする機能ではありません。

設定例:

```ini
[EnableFunction]
BrowserDragScroll=1

[BrowserDragScroll]
Firefox=1
Chrome=1
Edge=1
Explorer=1
```

### 7.14 AccelScroll

通常の縦 WheelUp／WheelDown をそのまま通し、ホイール速度に応じて `SendInput` による追加ホイールだけを送る加速機能です。

- 全体スイッチ: `[EnableFunction] AccelScroll=0`（既定 OFF）
- `[AccelScroll] MinThrottle=2`
- `[AccelScroll] MaxThrottle=10`
- `[AccelScroll] MinWheelSpeed=8`
- `[AccelScroll] MaxWheelSpeed=25`
- `[AccelScroll] ExcludeExe=`

最初の対象イベントは速度計測の起点になり、物理ホイールだけが届きます。同方向の次のイベントから速度を計算します。250 ms を超える間隔、方向変更、Ctrl／Shift／Alt／LWin／RWin の物理押下、L/R/M/X1/X2 マウスボタンの物理押下、対象外プロセスなどで加速状態をリセットします。

速度が `MinWheelSpeed` 未満なら throttle は1で追加分なし、`MaxWheelSpeed` 以上なら `MaxThrottle` です。その間は `MinThrottle` から `MaxThrottle` へ線形に増え、整数へ切り下げます。追加量は概念上 `(throttle - 1) × physical amount` で、1物理イベントにつき最大64です。

`MaxThrottle=10` は強い設定です。強すぎる場合は、正式既定値を変えるのではなく自分の INI で下げてください。Windows 11 実機で `MaxThrottle=4` が個人の好みに近かった例はありますが、正式既定値や一律の推奨値ではありません。

この実装には EMA、慣性、timer、fractional carry はありません。物理 amount には AutoHotkey v1 の `A_EventInfo` を使い、synthetic 追加送信方式は `SendInput` です。

#### ExcludeExe

加速しない実行ファイル名をカンマ区切りで指定します。

```ini
[AccelScroll]
ExcludeExe=firefox.exe,notepad.exe
```

- 前後の空白は除去します。
- 大文字小文字を区別しない exe basename の完全一致です。
- `.exe` で終わるファイル名だけを指定します。
- wildcard と full path は使えません。
- `\`、`/`、`:` を含む entry は無効です。
- 無効な entry だけを無視し、他の有効な entry は使います。
- 重複 entry は1件として扱います。

管理者権限で動く対象では、Windows の UIPI により synthetic 追加分が届かない場合があります。その場合でも native physical wheel は pass-through されます。

### 7.15 Wheel処理の優先順位

専用 Wheel 機能の判定順は次のとおりです。最初に処理した1機能だけで終了します。

1. Taskbar（StartWheel／TaskButtonWheel）
2. TrayWheelVolume
3. TabSwitch
4. ExplorerViewMode
5. SpecialScrollbarScroll
6. BrowserDragScroll

どの専用機能も対象にしなかった通常ホイールは MouseGestureL／OS 側へ通します。専用機能が捕捉したホイールは AccelScroll の状態をリセットします。専用処理が最後まで成立しなかった場合の replay は synthetic 入力として管理され、AccelScroll の対象にはなりません。

AccelScroll はこの blocking router には属さず、通常の物理ホイールを維持する専用 pass-through hotkey で動作します。修飾キー付きホイールでは加速状態のリセットだけを行い、Ctrl+Wheel zoom や Shift+Wheel などの native 操作を抑止しません。

## 8. INI設定リファレンス

### 8.1 固定スキーマ

「不正時」は、INI の値を変更せず実行中に使う値です。「既定値」は key がない場合に補完される値でもあります。

| Section | Key | 既定値 | 有効値 | 説明／不正時 |
|---|---|---:|---|---|
| `EnableFunction` | `AlwaysOnTop` | `1` | `0`, `1` | 機能全体。 0=OFF、1=ON。不正時 `1`。 |
| `EnableFunction` | `OpenExeFolder` | `1` | `0`, `1` | 機能全体。不正時 `1`。 |
| `EnableFunction` | `MoveDisabledWindow` | `1` | `0`, `1` | 機能全体。不正時 `1`。 |
| `EnableFunction` | `TabSwitch` | `1` | `0`, `1` | 機能全体。不正時 `1`。 |
| `EnableFunction` | `ExplorerViewMode` | `1` | `0`, `1` | 機能全体。不正時 `1`。 |
| `EnableFunction` | `Taskbar` | `1` | `0`, `1` | Taskbar／Tray 系の親スイッチ。不正時 `1`。 |
| `EnableFunction` | `AccelScroll` | `0` | `0`, `1` | 機能全体。不正時 `0`。 |
| `EnableFunction` | `SpecialScrollbarScroll` | `1` | `0`, `1` | 機能全体。不正時 `1`。 |
| `EnableFunction` | `BrowserDragScroll` | `1` | `0`, `1` | 機能全体。不正時 `1`。 |
| `General` | `Debug` | `0` | `0`, `1` | `OutputDebug` への診断出力。不正時 `0`。 |
| `AlwaysOnTop` | `FrameColor` | `0078D4` | 6桁 hex | 固定中の枠色。不正時 `0078D4`。 |
| `AlwaysOnTop` | `FrameThickness` | `3` | 整数 1～10 | 枠の太さ。不正時 `3`。 |
| `TabSwitch` | `Firefox` | `1` | `0`, `1` | Firefox adapter。不正時 `1`。 |
| `TabSwitch` | `Chrome` | `1` | `0`, `1` | Chrome adapter。不正時 `1`。 |
| `TabSwitch` | `Edge` | `1` | `0`, `1` | Edge adapter。不正時 `1`。 |
| `TabSwitch` | `Notepad` | `1` | `0`, `1` | Windows 11 メモ帳 adapter。不正時 `1`。 |
| `TabSwitch` | `Explorer` | `1` | `0`, `1` | Windows 11 エクスプローラー adapter。不正時 `1`。 |
| `TabSwitch` | `SysTabControl32` | `1` | `0`, `1` | classic tab adapter。不正時 `1`。 |
| `BrowserDragScroll` | `Firefox` | `1` | `0`, `1` | Firefox ブックマークサイドバー。不正時 `1`。 |
| `BrowserDragScroll` | `Chrome` | `1` | `0`, `1` | Chrome お気に入り／ブックマークサイドバー。不正時 `1`。 |
| `BrowserDragScroll` | `Edge` | `1` | `0`, `1` | Edge お気に入りサイドバー。不正時 `1`。 |
| `BrowserDragScroll` | `Explorer` | `1` | `0`, `1` | Windows 11 エクスプローラー右ペイン。不正時 `1`。 |
| `AccelScroll` | `MinThrottle` | `2` | 整数 1～16、`MinThrottle <= MaxThrottle` | throttle pair。不正 pair は `2 / 10`。 |
| `AccelScroll` | `MaxThrottle` | `10` | 整数 1～16、`MinThrottle <= MaxThrottle` | throttle pair。不正 pair は `2 / 10`。 |
| `AccelScroll` | `MinWheelSpeed` | `8` | 整数 1～100、`MinWheelSpeed < MaxWheelSpeed` | speed pair。不正 pair は `8 / 25`。 |
| `AccelScroll` | `MaxWheelSpeed` | `25` | 整数 1～100、`MinWheelSpeed < MaxWheelSpeed` | speed pair。不正 pair は `8 / 25`。 |
| `AccelScroll` | `ExcludeExe` | 空 | カンマ区切りの `.exe` basename | 無効 entry だけ無視。詳細は 7.14。 |
| `Taskbar` | `StartWheel` | `1` | `0`, `1` | スタートボタン上のホイール。不正時 `1`。 |
| `Taskbar` | `TaskButtonWheel` | `1` | `0`, `1` | タスクバーボタン上のホイール。不正時 `1`。 |
| `Taskbar` | `TaskButtonWheelMultiWindow` | `1` | `0`, `1` | 複数ウィンドウ処理。不正時 `1`。 |
| `Taskbar` | `TaskButtonMiddleClick` | `0` | `0`, `1` | 中クリックで通常 Close。不正時 `0`。 |
| `Taskbar` | `TaskButtonMiddleClickMultiWindow` | `0` | 整数 0～2 | 複数ウィンドウの Close mode。不正時 `0`。 |
| `Taskbar` | `TrayWheelVolume` | `1` | `0`, `1` | 通知領域上の音量操作。不正時 `1`。 |
| `Taskbar` | `TrayMiddleClickMute` | `1` | `0`, `1` | 通知領域中クリックの mute toggle。不正時 `1`。 |
| `Volume` | `Step` | `1` | 整数 1～10 | 1倍時の変更 percentage point。不正時 `1`。 |
| `Volume` | `AccelStrength` | `3` | 整数 1～5 | 音量加速の強さ。不正時 `3`。 |
| `VolumeOverlay` | `Enabled` | `1` | `0`, `1` | オーバーレイ表示。不正時 `1`。 |
| `VolumeOverlay` | `DurationMs` | `2000` | 整数 250～10000 | 表示時間。不正時 `2000`。 |
| `VolumeOverlay` | `MainColor` | `444444` | 6桁 hex | 表示色。不正時 `444444`。 |
| `SpecialScrollbarScroll` | `Vertical` | `-1` | `-2`, `-1`, 整数 0～10 | 縦軸。不正時 `-1`。 |
| `SpecialScrollbarScroll` | `Horizontal` | `-1` | `-2`, `-1`, 整数 0～10 | 横軸。不正時 `-1`。 |

Throttle pair と speed pair は別々に検証します。片方だけ不正でも、その pair 全体を safety fallback にします。例えば `MinThrottle=4`、`MaxThrottle=2` なら実行時は `2 / 10` です。INI 内の `4 / 2` 自体は書き換えません。

### 8.2 可変 rule section

| Section | Key | 形式 | 不正時 |
|---|---|---|---|
| `TabSpecial` | `RuleN` | `Class\|Title\|Left\|Top\|Width\|Height` | その rule を無視 |
| `TabIgnore` | `RuleN` | `Class\|Title` | その rule を無視 |

`RuleN` は N が1以上の整数のものだけを読み、N の昇順で評価します。詳細は「7.4 TabSwitch」を参照してください。

## 9. 対応確認済み／未対応／未確認

### 9.1 今回の Windows 11 実機環境で動作確認済みの例

SpecialScrollbarScroll の対象スクロールバーとして、次のアプリで動作が確認されています。

- エクスプローラー
- メモ帳
- システム情報（`msinfo32`）
- 7-Zip File Manager

これは各アプリ全体、全画面、全バージョンでの動作保証ではありません。

BrowserDragScroll は、Firefox／Chrome／Edge の対応するお気に入り・ブックマークサイドバーでの項目dragと、Windows 11 エクスプローラー右ペインでの selection rectangle drag／実ファイルdragについて、WheelDown／WheelUp、drag状態維持、対象別ON/OFFが確認されています。

### 9.2 SpecialScrollbarScrollで未対応と確認済み

SpecialScrollbarScroll は次のページ右端スクロールバーに対応していません。

- Firefox
- Chrome
- Edge

厳密な semantic hit-test 条件を満たさないためであり、geometry-only fallback で無理に捕捉しません。

### 9.3 未確認／保証外

- カスタム描画スクロールバーは保証しません。
- strict XAML/UIA の Horizontal は、十分に自然な実機対象がなく未実測です。
- 設定 key があるアプリでも、全バージョンや全 UI の互換性を保証するものではありません。
- 本節に明記していないアプリの互換性は推測しません。

## 10. 既知の制約

- Windows 11 を対象とします。
- MouseGestureL.ahk 1.41 を対象とします。
- AutoHotkey v1.1.37.02 Unicode 64-bit を対象とします。AHK v2 は非対応です。
- Firefox、Chrome、Edge のページ右端スクロールバーは SpecialScrollbarScroll では未対応です。
- カスタム描画スクロールバーは保証しません。
- strict XAML/UIA Horizontal は未実測です。
- StartWheel の復元時 Z-order は Windows 標準動作に依存します。
- elevated application では、権限差により AccelScroll の synthetic extra が届かない場合があります。native physical wheel は残ります。
- Native Helper を利用できない場合、必要とする TaskButton 系の対象解決が fail closed することがあります。
- 各機能は誤操作を避けるため対象を厳密に再確認します。判定が曖昧な場合は何もしないことがあります。
- drag中に極端に高速な連続ホイール入力を行うと、一時的に応答が遅くなる場合があります。

## 11. トラブルシューティング

### INIの変更が反映されない

保存後に MouseGestureL またはプラグインを再読み込みしてください。設定は読み込み時に反映されます。また、編集した INI が `MouseExtension_Win11.ahk` と同じフォルダーの `MouseExtension_Win11.ini` か確認してください。

### MouseExtensionNative.dllがない／読み込めない

配布物の `MouseExtensionNative.dll` を、名前を変えず `MouseExtension_Win11.ahk` と同じフォルダーへ置き、再読み込みしてください。64-bit Unicode 環境であることも確認してください。

### TaskButton系だけ動かない

`[EnableFunction] Taskbar=1` と、対象機能の key が `1` か確認してください。DLL の存在と配置も確認します。複数ウィンドウのタスクバーボタンは、`TaskButtonWheelMultiWindow=0` または `TaskButtonMiddleClickMultiWindow=0` なら意図的に何もしません。対象解決が曖昧な場合も fail closed します。

### AccelScrollが効かない

既定では OFF です。`[EnableFunction] AccelScroll=1` にして再読み込みしてください。対象 exe が `ExcludeExe` に含まれていないか、Ctrl／Shift／Alt／Win やマウスボタンを押したままではないかも確認します。最初の eligible event と250 msを超えた後の最初の event は native のみです。

### AccelScrollが強すぎる

`MaxThrottle` を下げて調整してください。`MinThrottle` と `MaxThrottle` はともに 1～16 で、`MinThrottle <= MaxThrottle` が必要です。設定関係が不正だと pair 全体が実行時 `2 / 10` へ戻るため、意図せず強く感じることがあります。

### 特定exeだけAccelScrollを無効にしたい

`ExcludeExe` に exe basename をカンマ区切りで記載します。

```ini
[AccelScroll]
ExcludeExe=firefox.exe,notepad.exe
```

full path や wildcard は使わないでください。

### 管理者権限アプリでAccelScrollの加速分が効かない

Windows の権限分離により `SendInput` の synthetic extra が届かない場合があります。native physical wheel は pass-through されるため、通常量のスクロールだけが見える場合があります。

### ブラウザーの右端スクロールバーでSpecialScrollbarScrollが効かない

Firefox、Chrome、Edge のページ右端スクロールバーは SpecialScrollbarScroll では未対応です。設定ミスではありません。通常のホイール操作を使ってください。

### 不正なINI値を設定した

不正値は INI に自動修正されません。実行中は既定値または指定された safety fallback を使います。「8. INI設定リファレンス」で有効範囲を確認して修正し、再読み込みしてください。

### SpecialScrollbarScrollをONにしたが動かない

全体スイッチに加え、対象軸を `1`～`10`、`-1`、`-2` のいずれかにします。`Vertical=0` と `Horizontal=0` のままでは処理しません。カーソルが対応するスクロールバーそのものの上にあることも確認してください。

## 12. FAQ

### Q. FirefoxだけAccelScrollを無効にできますか？

はい。次のように指定します。

```ini
[AccelScroll]
ExcludeExe=firefox.exe
```

### Q. AccelScrollが強すぎます。

`MaxThrottle` を下げてください。正式既定値は10ですが、利用環境や好みに合わせて調整できます。`MinThrottle <= MaxThrottle` を守ってください。

### Q. TaskButtonWheelで複数windowを扱うには？

既定で `[Taskbar] TaskButtonWheelMultiWindow=1` です。`0` に変更している場合は `1` に戻して再読み込みします。この機能が最小化したウィンドウは、WheelUp で LIFO 順に復元されます。

### Q. TaskButtonMiddleClickでグループ全体を閉じられますか？

`TaskButtonMiddleClick=1` に加え、`TaskButtonMiddleClickMultiWindow=2` を指定します。検証済み候補へ通常の閉じる要求を送るもので、強制終了ではありません。mode `1` は1ウィンドウだけ、mode `0` は複数時に何もしません。

### Q. SpecialScrollbarScrollの-1と-2は何が違いますか？

`-1` は1ページ分の増減、`-2` は先頭側／末尾側への移動です。WheelUp が decrement／先頭側、WheelDown が increment／末尾側です。

### Q. Chromeの右端scrollbarでも使えますか？

いいえ。Chrome のページ右端スクロールバーは SpecialScrollbarScroll では未対応です。Firefox と Edge も同様です。

### Q. AHK v2で使えますか？

使えません。AutoHotkey v1.1.37.02 Unicode 64-bit が対象です。

### Q. INIを消さないとアップデートできませんか？

通常は不要です。固定スキーマの不足 key／section は自動補完され、既存値は原則維持されます。不正な既存値は書き換えられないため、必要なら手動で修正してください。

### Q. Ctrl+WheelやShift+WheelはAccelScrollに奪われませんか？

奪いません。修飾キー付きホイールは加速状態のリセットだけを行い、native modifier+wheel を pass-through します。

### Q. DLLがなくても他の機能はすべて停止しますか？

必ずしも停止しません。Native Helper が利用不能になり、それを必要とする TaskButton 系の対象解決が安全側で中止される場合があります。

## 13. 今後の候補

`LongPressDoubleClick` は v1.1.1 では未実装で、今後の候補です。

- LongPressDoubleClick

廃止されたという意味ではありませんが、将来の実装を保証するものでもありません。v1.1.1 の INI スキーマには placeholder がありません。古い INI に関連 key や section が残っていても、v1.1.1 では使用せず、自動削除もしません。

## ライセンス

MouseExtension_Win11 は MIT License で提供されます。詳細は `LICENSE` を参照してください。

MouseGestureL 1.41 本体は MouseExtension_Win11 の配布物には含まれません。MouseGestureL その他の第三者ソフトウェアには、それぞれのライセンス条件が適用されます。
