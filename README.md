# XIUIJP

[XIUI](https://github.com/tirem/XIUI)（Ashita v4 向け FFXI UI アドオン）の日本語化フォークです。

ゲーム内のアドオン名は本家と同じ **XIUI** です。GitHub 上のリポジトリ名だけ **XIUIJP** にしています。

## 導入（CatsEyeXI）

1. ZIP を解凍すると `XIUIJP-main` のようなフォルダになります。中身（`XIUI.lua` と `modules` がある階層）を **`Ashita/addons/XIUI`** に置いてください。フォルダ名を `XIUIJP` のままにしないでください。
2. 本家 XIUI の上に一部だけ重ねないでください。一度フォルダを退避してから、このフォーク一式で置き換えてください。混ざると `CHARGE_TIMER` が nil で起動に失敗します。
3. ランチャーが本家 XIUI で上書きしないよう、`cexi_settings.json` の `IgnoreUpdatesAddons` に `XIUI` を入れてください（例: `fancychat,FancyCompass,XIUI,zonename`）。
4. ゲーム内で `/addon reload xiui` するか、クライアントを出し直してください。

日本語の設定画面・ホットバーラベルには、ImGui 既定フォントに日本語グリフ（起動プロファイルの Meiryo `is_jp` など）が必要です。チャット本文の日本語とは別です。

## 導入（VanaCore）

VanaCore では、CatsEye 用のフォルダコピーとは別に、日本語表示用のセットアップを配しています。アドオン本体ではありません。すでに入っている XIUIJP と FancyChatJP の上へ、必要なファイルだけ重ねます。

ダウンロード: [VanaCore.zip](https://github.com/handomade/XIUIJP/releases/download/1.8.4i/VanaCore.zip)（[Releases](https://github.com/handomade/XIUIJP/releases)）。解凍すると `VanaCore日本語セットアップ` フォルダになります。

1. VanaCore と Ashita を終了する
2. zip を解凍し、そのフォルダを **Ashita フォルダと Vanacore フォルダが並んでいる場所**に置く
3. `適用.bat` を実行する

行うことは次のとおりです。

- `Vanacore\vanacore.ini` に `ashita.interface=4.30` を書く
- その人の Ashita の `imgui.ini` から、FancyChat のウィンドウ位置を VanaCore 側へ写す
- XIUI と FancyChat の VanaCore 向けファイルを、Ashita と VanaCore の両方のアドオンフォルダへ入れる
- PC に Meiryo があり VanaCore 側に無いときだけ、`resources\fonts\meiryo.ttc` へコピーする
- 戦闘ログの魔法アイコン用 `gameicons.ttf` を、VanaCore が読む場所へコピーする

変える前のファイルは、そのフォルダの `backup` に残ります。終わったら VanaCore を起動し直してください。`1.8.4i` は、VanaCore（Ashita interface 4.3）で通知・詠唱名・ホットバーの日本語を ImGui の文字として描きます。CatsEye（4.16）の描画は変えていません。CatsEyeXI ではこの bat は使いません。

## 本家から追加・改変した点

- 設定画面とコマンド説明の日本語オーバーレイ（`locale/ja.lua`）。本家の英語ソースは残し、表示だけ差し替えます
- 日本語クライアント向けに、マクロ実行名を DAT の日本語名（例: `/ma "ケアル"`）へ寄せます
- ホットバー／クロスバーのマウスオーバーとアクションラベルで日本語を表示します（ImGui 既定フォントの日本語グリフを利用）
- バージョン表記は本家 v1.8.4（2026-09-23 タグ `e7e390b`）に `i` を付けた `1.8.4i` です。作者に Hando を追加しています。`i` は VanaCore（Ashita interface 4.3）で通知・詠唱名・ホットバーの日本語を ImGui の文字として描き、CatsEye（4.16）の描画はそのままです

未翻訳の設定項目は英語のまま出ます。`locale/ja.lua` に本家と同じ英語キーで追記すれば足せます。

## 本家

- 上流: https://github.com/tirem/XIUI
- このフォーク: https://github.com/handomade/XIUIJP
