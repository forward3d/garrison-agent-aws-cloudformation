FROM ruby:2.5.3-alpine3.8 as build
MAINTAINER developers@forward3d.com

RUN mkdir -p /usr/src/garrison-agent
WORKDIR /usr/src/garrison-agent

COPY Gemfile Gemfile.lock /usr/src/garrison-agent/
RUN bundle install --jobs "$(getconf _NPROCESSORS_ONLN)" --retry 5 --without development

COPY . /usr/src/garrison-agent

RUN rm /usr/local/bundle/cache/*.gem
RUN find /usr/local/bundle -iname '*.o' -exec rm {} \;
RUN find /usr/local/bundle -iname '*.a' -exec rm {} \;


# RUNTIME CONTAINER
FROM ruby:2.5.3-alpine3.8

WORKDIR /usr/src/garrison-agent
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /usr/src/garrison-agent /usr/src/garrison-agent

ENV PATH "$PATH:/usr/src/garrison-agent/bin"
