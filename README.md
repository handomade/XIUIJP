# XIUIJP

[XIUI](https://github.com/tirem/XIUI)（Ashita v4 向け FFXI UI アドオン）の日本語化フォークです。

ゲーム内のアドオン名は本家と同じ **XIUI** です。GitHub 上のリポジトリ名だけ **XIUIJP** にしています。

## 導入（CatsEyeXI）

1. ZIP を解凍すると `XIUIJP-main` のようなフォルダになります。中身（`XIUI.lua` と `modules` がある階層）を **`Ashita/addons/XIUI`** に置いてください。フォルダ名を `XIUIJP` のままにしないでください。
2. 本家 XIUI の上に一部だけ重ねないでください。一度フォルダを退避してから、このフォーク一式で置き換えてください。混ざると `CHARGE_TIMER` が nil で起動に失敗します。
3. ランチャーが本家 XIUI で上書きしないよう、`cexi_settings.json` の `IgnoreUpdatesAddons` に `XIUI` を入れてください（例: `fancychat,FancyCompass,XIUI,zonename`）。
4. ゲーム内で `/addon reload xiui` するか、クライアントを出し直してください。

日本語の設定画面・ホットバーラベルには、ImGui 既定フォントに日本語グリフ（起動プロファイルの Meiryo `is_jp` など）が必要です。チャット本文の日本語とは別です。

## 本家から追加・改変した点

- 設定画面とコマンド説明の日本語オーバーレイ（`locale/ja.lua`）。本家の英語ソースは残し、表示だけ差し替えます
- 日本語クライアント向けに、マクロ実行名を DAT の日本語名（例: `/ma "ケアル"`）へ寄せます
- ホットバー／クロスバーのマウスオーバーとアクションラベルで日本語を表示します（ImGui 既定フォントの日本語グリフを利用）
- バージョン表記は本家 v1.8.4（2026-09-23 タグ `e7e390b`）に `h` を付けた `1.8.4h` です。作者に Hando を追加しています

未翻訳の設定項目は英語のまま出ます。`locale/ja.lua` に本家と同じ英語キーで追記すれば足せます。

## 本家

- 上流: https://github.com/tirem/XIUI
- このフォーク: https://github.com/handomade/XIUIJP
