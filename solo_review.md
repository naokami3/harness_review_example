# Rails タスク管理API コードレビュー

## セキュリティ

### 1. [Critical] JWT署名の検証が無効化されている

**ファイル:** `app/controllers/application_controller.rb:8`

```ruby
decoded = JWT.decode(token, secret_key, false)
```

第3引数が`false`のため、署名検証がスキップされている。攻撃者が任意の`user_id`を含むトークンを偽造でき、他ユーザーへのなりすましが可能。

**修正案:**
```ruby
decoded = JWT.decode(token, secret_key, true, { algorithm: 'HS256' })
```

### 2. [Critical] タスク操作に所有者チェックがない

**ファイル:** `app/controllers/tasks_controller.rb:47-49`

```ruby
def set_task
  @task = Task.find(params[:id])
end
```

`Task.find`は全タスクから検索するため、認証済みユーザーが他ユーザーのタスクを閲覧・更新・削除できる（IDOR脆弱性）。

**修正案:**
```ruby
def set_task
  @task = current_user.tasks.find(params[:id])
end
```

### 3. [High] JWTシークレットキーのフォールバック値がハードコードされている

**ファイル:** `app/controllers/application_controller.rb:18-20`

```ruby
def secret_key
  ENV['JWT_SECRET_KEY'] || 'fallback-secret'
end
```

環境変数が未設定の場合、推測可能なシークレットが使用される。本番環境でトークン偽造のリスクがある。

**修正案:**
```ruby
def secret_key
  ENV.fetch('JWT_SECRET_KEY') # 未設定なら例外で起動を止める
end
```

### 4. [Medium] JWTの署名アルゴリズムが指定されていない

**ファイル:** `app/controllers/auth_controller.rb:14`

```ruby
token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, secret_key)
```

アルゴリズムが明示されておらず、デコード側でも検証していないため、アルゴリズム置換攻撃（`none`アルゴリズム等）のリスクがある。

**修正案:**
```ruby
token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i }, secret_key, 'HS256')
```

---

## バグ

### 5. [High] 論理削除されたタスクが一覧・検索に表示される

**ファイル:** `app/controllers/tasks_controller.rb:10, 41`

`index`と`by_status`で`deleted_at`がNULLでないレコードも返却される。論理削除の意味をなしていない。

**修正案:**
```ruby
# Taskモデルにデフォルトスコープまたは明示的スコープを追加
class Task < ApplicationRecord
  scope :active, -> { where(deleted_at: nil) }
end

# コントローラーで使用
tasks = current_user.tasks.active.offset(offset).limit(per_page)
```

### 6. [Medium] ページネーションのpageパラメータが0始まり

**ファイル:** `app/controllers/tasks_controller.rb:6-8`

```ruby
page     = params[:page].to_i
per_page = (params[:per_page] || 20).to_i
offset   = page * per_page
```

`page`パラメータ未指定時は`nil.to_i`で`0`になり動作するが、一般的なAPI規約（1始まり）と異なり混乱を招く。また負の値やper_pageに0が渡された場合のバリデーションがない。

**修正案:**
```ruby
page     = [params.fetch(:page, 1).to_i, 1].max
per_page = [params.fetch(:per_page, 20).to_i.clamp(1, 100)]
offset   = (page - 1) * per_page
```

### 7. [Low] destroyアクションが論理削除済みタスクを再度削除できる

**ファイル:** `app/controllers/tasks_controller.rb:36-38`

```ruby
def destroy
  @task.update!(deleted_at: Time.current)
  render json: @task
end
```

既に`deleted_at`が設定済みのタスクに対しても実行でき、タイムスタンプが上書きされる。

---

## 設計

### 8. [Medium] シークレットキーの取得ロジックが重複している

`ApplicationController#secret_key`と`spec/requests/tasks_spec.rb:6`で同じロジックが重複。シークレット管理は`Rails.application.credentials`や専用の設定クラスに集約すべき。

### 9. [Low] Taskモデルにステータスのバリデーションがない

**ファイル:** `app/models/task.rb`

`status`フィールドに任意の文字列を設定可能。不正な値が保存される。

**修正案:**
```ruby
class Task < ApplicationRecord
  STATUSES = %w[todo in_progress done].freeze
  validates :status, inclusion: { in: STATUSES }
end
```

### 10. [Low] priorityのバリデーションがない

**ファイル:** `app/models/task.rb`

`priority`に負の値や極端に大きな値を設定可能。

**修正案:**
```ruby
validates :priority, numericality: { in: 1..5 }
```

### 11. [Info] `config.ru`に不要な行がある

**ファイル:** `config.ru:4`

```ruby
Rails.application.load_server
```

Rails 7.2では不要。`run Rails.application`のみで十分。

---

## 指摘サマリー

| 重要度 | 件数 | 内容 |
|--------|------|------|
| Critical | 2 | JWT署名未検証、IDOR脆弱性 |
| High | 2 | シークレットキーのフォールバック、論理削除の不備 |
| Medium | 3 | アルゴリズム未指定、ページネーション、シークレット重複 |
| Low | 3 | 再削除可能、ステータス/優先度バリデーション不足 |
| Info | 1 | config.ruの不要行 |
