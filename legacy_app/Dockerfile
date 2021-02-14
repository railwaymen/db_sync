FROM ruby:3.0

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

WORKDIR /usr/src/app
COPY Gemfile* ./
RUN bundle install
COPY . .

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]