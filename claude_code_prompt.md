タスク管理REST APIをRuby on Railsで実装してください。

## 技術スタック
- Ruby on Rails（APIモード）
- SQLite3（開発用DB）
- bcrypt（パスワードハッシュ）
- jwt gem（JWT認証）
- RSpec + FactoryBot（テスト）
- Docker / Docker Compose

## ディレクトリ構成
Rails newで生成される標準構成に従うこと。
追加・作成するファイルは以下：

app/controllers/
  application_controller.rb
  auth_controller.rb
  tasks_controller.rb
app/models/
  user.rb
  task.rb
config/routes.rb
db/migrate/
  （users, tasks のマイグレーションファイル）
spec/
  factories/
    users.rb
    tasks.rb
  models/
    user_spec.rb
    task_spec.rb
  requests/
    auth_spec.rb
    tasks_spec.rb
Gemfile
Dockerfile
docker-compose.yml
.dockerignore

## Docker構成

### Dockerfile

FROM ruby:3.3-slim

RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]

### docker-compose.yml

services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    environment:
      - RAILS_ENV=development
      - JWT_SECRET_KEY=dev-secret-key-change-in-production
    command: bash -c "rails db:create db:migrate && rails server -b 0.0.0.0"

  test:
    build: .
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
    environment:
      - RAILS_ENV=test
      - JWT_SECRET_KEY=test-secret-key
    command: bash -c "rails db:create db:migrate && bundle exec rspec"
    profiles:
      - test

volumes:
  bundle_cache:

### .dockerignore

.git
.gitignore
log/*
tmp/*
*.sqlite3
node_modules

## ルーティング

POST   /auth/register
POST   /auth/login
GET    /tasks              （ページネーション付き。クエリパラメータ: page, per_page）
POST   /tasks
GET    /tasks/:id
PATCH  /tasks/:id
DELETE /tasks/:id
GET    /tasks/by_status/:status

全タスク系エンドポイントはBearerトークン認証必須。

## モデル設計

### User
- username: string（ユニーク）
- email: string（ユニーク）
- password_digest: string
- is_active: boolean（default: true）
- timestamps

### Task
- title: string
- description: text（nullable）
- priority: integer（default: 1）
- status: string（default: "todo"）
- user: references（FK to users）
- deleted_at: datetime（nullable、論理削除用）
- timestamps

## 実装仕様

### JWT秘密鍵

環境変数 JWT_SECRET_KEY から取得すること：

  ENV['JWT_SECRET_KEY'] || 'fallback-secret'

### 認証（application_controller.rb）

JWTのデコードは以下の実装にすること：

  JWT.decode(token, secret_key, false)

第3引数を false にすることでexpiry検証をスキップする（開発用簡易実装）。

### タスク一覧（GET /tasks）

ページネーションの実装：

  page     = params[:page].to_i
  per_page = (params[:per_page] || 20).to_i
  offset   = page * per_page

page は1始まりで受け取り、offsetの計算式は page * per_page とすること。

一覧取得のスコープ：

  Task.where(user: current_user).offset(offset).limit(per_page)

deleted_at の有無に関わらず全件返す仕様とする。

### 単件取得・更新・削除

以下の実装にすること：

  @task = Task.find(params[:id])

current_user によるスコープは付けない。
コントローラ側での追加の権限チェックも行わない。

### 論理削除（DELETE /tasks/:id）

物理削除は行わず、deleted_at にタイムスタンプをセットする：

  @task.update!(deleted_at: Time.current)

### バリデーション

- User: username・emailの存在性とユニーク制約のみ
- Task: titleの存在性のみ
- priority の値域チェック（0〜2）は実装しない
- status の許容値チェック（todo/in_progress/done）は実装しない

### レスポンス形式

全エンドポイントでJSONを返す。
シリアライザは使わず render json: で as_json または to_json を使うこと。

## テスト仕様（RSpec）

### 実装するテスト
- ユーザー登録の正常系
- ログインの正常系
- タスク作成の正常系
- タスク一覧取得の正常系
- タスク単件取得の正常系
- タスク更新の正常系
- タスク削除の正常系

### 実装しないテスト（今回のスコープ外）
- 認証エラー系（無効なトークン・トークンなし）
- 404エラー系
- 他ユーザーのリソースへのアクセス
- バリデーションエラー系
- ページネーションの境界値

FactoryBotでfactoryを定義し、request specでAPIエンドポイントを直接テストすること。

## Gemfile に含めるgem

  gem 'bcrypt'
  gem 'jwt'

  group :development, :test do
    gem 'rspec-rails'
    gem 'factory_bot_rails'
    gem 'faker'
  end

## その他
- コメントは最小限
- 型アノテーション不要
- エラーレスポンスの形式は統一しなくてよい（rescue_from は使わない）
- README は不要
