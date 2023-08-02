## マルチステージビルド
# 2022年11月時点の最新安定版Rubyの軽量版「alpine」
FROM ruby:3.1.2-alpine AS builder
# 言語設定
ENV LANG=C.UTF-8
# タイムゾーン設定
ENV TZ=Asia/Tokyo
# 2022年11月時点の最新版のbundler
# bundlerのバージョンを固定するための設定
ENV BUNDLER_VERSION=2.3.25
# インストール可能なパッケージ一覧の更新
RUN apk update && apk upgrade && apk add --virtual build-dependencies build-base
RUN apk add --no-cache alpine-sdk build-base curl-dev mysql-dev tzdata
RUN apk add --no-cache ruby-dev libc-dev linux-headers libxml2-dev libxslt-dev
RUN apk add gcompat

# 作業ディレクトリの指定
ENV APP_ROOT /app/webapp
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT
# Railsのインストール
RUN gem install rails
# ローカルにあるGemfileとGemfile.lockをコンテナ内のディレクトリにコピー
COPY Gemfile Gemfile.lock ./
# bundlerのバージョンを固定する
RUN gem install bundler -v $BUNDLER_VERSION
# bunlde installを実行する
RUN bundle config --local set path 'vendor/bundle'
RUN bundle install --jobs=4 --without development test
COPY . ./
# build-packsを削除
# RUN apk del build-packs

## マルチステージビルド
# 2022年11月時点の最新安定版Rubyの軽量版「alpine」
FROM ruby:3.1.2-alpine
# 言語設定
ENV LANG=C.UTF-8
# タイムゾーン設定
ENV TZ=Asia/Tokyo
# 本番環境用のRAILS_ENV設定
ENV RAILS_ENV=production
# インストール可能なパッケージ一覧の更新
RUN apk update && apk upgrade && apk add --virtual build-dependencies build-base
RUN apk add --no-cache bash mysql-dev tzdata
RUN apk add --no-cache ruby-dev libc-dev linux-headers libxml2-dev libxslt-dev
RUN apk add --no-cache gcompat

# 作業ディレクトリの指定
ENV APP_ROOT /app/webapp
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT
# ビルドステージからファイルをコピー
COPY --from=builder $APP_ROOT $APP_ROOT
# Railsのインストール
RUN gem install rails
# puma.sockを配置するディレクトリを作成
RUN mkdir -p tmp/sockets
# 本番環境（AWS ECS）でNginxへのファイル共有用ボリューム
VOLUME $APP_ROOT/public
VOLUME $APP_ROOT/tmp
# コンテナ起動時に実行するスクリプト
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb", "bundle exec rails s -p 3000 -b '0.0.0.0'"]