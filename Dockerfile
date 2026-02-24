FROM ruby:4.0-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential git && \
  rm -rf /var/lib/apt/lists/*

RUN bundle config set path /bundle

WORKDIR /app

ENTRYPOINT ["sh", "-c", "bundle install --quiet && exec bundle exec \"$@\"", "--"]
CMD ["rake", "integration"]
