# harness_review_example

Anthropicのハーネス設計に関するエンジニアリングブログを読んで、Claude Codeで実際にどこまで再現できるか試した実験リポジトリ。

## 背景

Anthropicが公開しているエンジニアリングブログ（[Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps)）を読んだ。

内容を要約すると、AIコーディングエージェントを単体で使うのではなく、複数のエージェントに役割を分担させる「ハーネス」と呼ばれる仕組みを作ることで、単独エージェントでは解決できない問題に対処できるという話。

記事の中で特に刺さったのは自己評価の問題で、エージェントは自分が作ったものを評価させると必ず甘くなる。Evaluatorを別エージェントとして分離し、懐疑的に振る舞うよう調整する方が、Generatorに自分のコードを批判させようとするよりずっと効きが良いという指摘だった。

コードレビューはこの構造との相性が良い。実装するエージェント（Generator）と、それをレビューするエージェント（Evaluator）に分けることで、自己評価の甘さを回避できるはず。これをClaude CodeのSkillとして実装することを最終ゴールに置いた。

## このリポジトリの役割

単独エージェントによるレビューとハーネスを使ったレビューの差を比較するためのサンプルコード。

対象は **Ruby on Rails製のタスク管理REST API**。実際の開発現場で出てきそうな規模感（7ファイル、認証付き）で、普通のレビューでは見逃しやすいバグを意図的に仕込んである。

普通にClaude Codeへ「このコードをレビューして」と依頼した場合と、GeneratorとEvaluatorを分離したハーネスで回した場合を比較し、どのような差が出るかを記録する。

## 意図的に仕込んだバグ

このAPIは**意図的に問題を含んでいる**。実験用のサンプルなので動作確認を目的にしないこと。

### 深い問題（普通のレビューで見逃されやすいもの）

**① JWTの有効期限が検証されない**
```ruby
JWT.decode(token, secret_key, false)
```

第3引数を`false`にしているため、有効期限切れのトークンでも認証が通る。

**② 他ユーザーのタスクが取得・更新・削除できる**
```ruby
@task = Task.find(params[:id])
```

`current_user`によるスコープを付けていないため、task_idを知っていれば別ユーザーのタスクを操作できる。正しくは`current_user.tasks.find(params[:id])`。

**③ 論理削除が一覧に反映されない**
```ruby
# 削除時にdeleted_atをセットするが…
@task.update!(deleted_at: Time.current)

# 一覧取得でフィルタしていない
Task.where(user: current_user).offset(offset).limit(per_page)
```

削除済みタスクが一覧に出続ける。`where(deleted_at: nil)`が抜けている。

### 中程度の問題

**④ ページネーションが常に1ページ目を読み飛ばす**
```ruby
offset = page * per_page  # page=1のとき offset=20 になる
```

正しくは`(page - 1) * per_page`。page=1で最初の20件が返らない。

**⑤ priorityとstatusの値域チェックがない**

priority=-1やstatus="invalid"もそのまま保存できる。

### 表面的な問題（普通のレビューでも拾える）

- テストが正常系のみ。権限エラー・404・バリデーションエラーのテストがない
- エラーレスポンスの形式が統一されていない
- docコメントなし

## ゴール

このサンプルを使って以下を実験・記録する：

1. 単独エージェントに「このコードをレビューして」と依頼した場合の指摘内容
2. Generator（実装確認）→ Evaluator（厳しくレビュー）→ Generator（修正）のハーネスで回した場合の指摘内容
3. 差分の分析 → どのバグがどちらで検出されたか
4. ハーネスをClaude CodeのSkillとして整備する

## エンドポイント

| Method | Path | 説明 |
|--------|------|------|
| POST | /auth/register | ユーザー登録 |
| POST | /auth/login | JWT発行 |
| GET | /tasks | タスク一覧（ページネーション付き） |
| POST | /tasks | タスク作成 |
| GET | /tasks/:id | タスク単件取得 |
| PATCH | /tasks/:id | タスク更新 |
| DELETE | /tasks/:id | タスク削除（論理削除） |
| GET | /tasks/by_status/:status | ステータスでフィルタ |

## 参考

- [Harness design for long-running application development - Anthropic](https://www.anthropic.com/engineering/harness-design-long-running-apps)
- [Effective harnesses for long-running agents - Anthropic](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Building Effective Agents - Anthropic](https://www.anthropic.com/research/building-effective-agents)
