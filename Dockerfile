FROM ruby:2.1.5
MAINTAINER mdocuhement

RUN mkdir -p /usr/src/app
RUN mkdir -p /data/storage
RUN mkdir -p /data/db
WORKDIR /usr/src/app

ENV RAILS_ENV production
ENV SECRET_KEY_BASE 9489b3eee4eccf317ed77407553e8adc97baca7c74dc7ee33cd93e4c8b69477eea66eaedeb18af0be2679887c7c69c0a28c0fded0a71ea472a8c4laalal19cb
ENV STORAGE_DIRECTORY /data/storage
ENV DATABASE_PATH /data/db/production.sqlite3

RUN mkdir -p tmp/pids
COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/
# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1
RUN bundle install --deployment --without development test


COPY . /usr/src/app

RUN apt-get update && apt-get install -y nodejs --no-install-recommends && rm -rf /var/lib/apt/lists/*

RUN bundle exec rake db:migrate

VOLUME /data/storage
VOLUME /data/db
EXPOSE 10001
CMD bundle exec rake db:migrate && bundle exec rails s -p 10001
