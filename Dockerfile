FROM ruby:2.7.4-alpine
COPY . /usr/src/app
VOLUME /usr/src/app

WORKDIR /usr/src/app

RUN apk add --update nodejs g++ make
RUN apk add gcompat
RUN gem install bundler -v 2.2.33
RUN bundle install
RUN apk add --no-cache bash

CMD tail -f /dev/null
