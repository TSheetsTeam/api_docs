FROM ruby:2.3-alpine
COPY . /usr/src/app
VOLUME /usr/src/app

WORKDIR /usr/src/app

RUN apk add --update nodejs g++ make
RUN bundle install
RUN apk add --no-cache bash

CMD tail -f /dev/null