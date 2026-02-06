FROM ruby:4.0-slim

RUN bundle config set path /bundle

WORKDIR /app

ENTRYPOINT ["sh", "-c", "bundle install --quiet && exec bundle exec \"$@\"", "--"]
CMD ["rake", "integration"]
