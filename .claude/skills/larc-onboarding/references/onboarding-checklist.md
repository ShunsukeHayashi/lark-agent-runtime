# LARC Onboarding Checklist

## 入口の固定

- [ ] ユーザー向け会話入口は OpenClaw Feishu/Lark channel の bot / chat app と明記した
- [ ] `lark-cli` の App ID / App Secret は別の chat app ではないと説明した

## 接続レイヤー

- [ ] OpenClaw が入っている
- [ ] `openclaw channels login --channel feishu` を完了した
- [ ] pairing / allowlist / mention 条件を確認した
- [ ] official `openclaw-lark` plugin が使える

## Runtime レイヤー

- [ ] `larc-runtime` skill を入れた
- [ ] `lark-cli config init` を完了した
- [ ] `lark-cli auth login` を完了した
- [ ] `larc quickstart` を完了した

## 検証

- [ ] `larc status` が通る
- [ ] `larc ingress enqueue` が通る
- [ ] `larc ingress openclaw` が通る
- [ ] テストユーザーが正しい bot / chat app に送れている

## 禁止事項

- [ ] LARC 用認証アプリをユーザー向け chat app として案内していない
- [ ] experimental IM daemon loop を主要オンボーディング導線にしていない
