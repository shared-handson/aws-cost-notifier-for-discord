# 適用方法

.github フォルダを使いたいリポジトリの直下に丸ごとコピーすれば OK。  
特に大事なのが以下の２つのフォルダ。

- .github/actions
- .github/workflows

# 使い方

## terraform-plan

main ブランチへのプルリクで自動的に起動される。  
成功したら terraform plan の結果がプルリクのコメントで出力されるので待つ。  
失敗したら失敗理由がプルリクのコメントで出力されて、自動的にプルリクがクローズする。

## terraform-apply

プルリクをマージしたら自動的に起動される。  
terraform-plan が終わってから実行すること。じゃないと失敗する。  
終わったら Discord チャンネルに通知される。

## terraform-destroy-plan

Github Actions を手動実行で破棄内容を確認する。  
終わったら Discord チャンネルに通知される。  
結果は Workflow を直接見る。

1. Github のリポジトリページ
2. 画面内の Actions タブ
3. 左メニューから 「Terraform Manual - destroy plan」
4. 「Run workflow」のドロップダウンメニュー
5. 「Branch: main」
6. 「Run workflow」の緑ボタンで実行

## terraform-destroy-exec

Github Actions を手動実行で破棄を実行する。  
終わったら Discord チャンネルに通知される。  
結果は Workflow を直接見る。

1. Github のリポジトリページ
2. 画面内の Actions タブ
3. 左メニューから 「Terraform Manual - destroy exec」
4. 「Run workflow」のドロップダウンメニュー
5. 「Branch: main」
6. 「Run workflow」の緑ボタンで実行

# secrets

以下は Organizaions の共用 secrets として登録しているが変動値の為、
メンテが必要。

- GH_DC_USERMAP
  - Github と Discord のユーザー ID のマッピング
  - メンバーが増えたらメンテナンスする
  - Discord のユーザー ID は開発者モードを ON にしてユーザー右クリック
  - 例)
    ```
    {
      "githubname1": "012345678901234567",
      "githubname2": "9876543210987654321"
    }
    ```

以下は全て Organizaions の共用 secrets として登録していて固定値の為、
基本的には新規登録などは不要。

- AWS_IAM_ROLE
  - 展開先の AWS の IAM ロールの ARN
  - 例）　`arn:aws:iam::xxxxxxxxxxxx:role/IAM-ROLE`
- AWS_TF_STATE_BUCKET
  - バックエンドとして使う S3 のバケット名
  - 例) `tf-state-xxxxxxxxxxxx`
- DC_WEBHOOK_GHAC
  - 通知先の Discord チャンネルの Webhook URL
  - 例) `https://discord.com/api/webhooks/xxxxxxxxxxxxxxxxxxx/xxxxxxxxxxxxxxxxxxx`
