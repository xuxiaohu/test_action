FROM ruby:2.7.1 AS builder
ENV LANG C.UTF-8
ENV RAILS_ENV production
ENV MYSQL_DB_ADAPTER nulldb

RUN apt-get update && \
    apt-get install -y nodejs \
                       vim \
                       default-mysql-client \
                       default-libmysqlclient-dev \
                       --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# RUN rm /usr/lib/x86_64-linux-gnu/libssl.so && ln -nfs /usr/lib/x86_64-linux-gnu/libssl.so.1.0.2 /usr/lib/x86_64-linux-gnu/libssl.so

#Cache bundle install
WORKDIR /tmp
ADD ./Gemfile Gemfile
ADD ./Gemfile.lock Gemfile.lock
RUN gem install bundler:2.0.1
RUN bundle install

ENV APP_ROOT /app
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT
COPY . $APP_ROOT
COPY env $APP_ROOT/.env
RUN mkdir -p $APP_ROOT/tmp/pids

WORKDIR $APP_ROOT
RUN SKIP_APP_CACHE=true bundle exec rake assets:precompile

VOLUME ["$APP_ROOT/public"]

EXPOSE  3000
CMD ["rails", "server", "-b", "0.0.0.0"]

FROM madnight/docker-alpine-wkhtmltopdf as wkhtmltopdf

FROM ruby:2.7.1 as deploy
LABEL maintainer="lixiumiao@gmail.com"
ENV RAILS_ENV production
ENV LANG C.UTF-8

ENV APP_ROOT /app
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_SERVE_STATIC_FILES true

RUN apt-get update && \
    apt-get install -y nodejs \
                       vim \
                       default-mysql-client \
                       default-libmysqlclient-dev \
                       --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

WORKDIR $APP_ROOT
RUN gem install bundler -v 2.0.1 && gem install rake  -v 12.3.3  
RUN mkdir -p tmp/pids && mkdir -p log && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" >  /etc/timezone
COPY --from=wkhtmltopdf /bin/wkhtmltopdf /bin/

COPY --from=builder $GEM_HOME $GEM_HOME
COPY --from=builder $APP_ROOT $APP_ROOT

RUN date -u > BUILD_TIME

EXPOSE  3000
CMD ["rails", "server", "-b", "0.0.0.0", "-e", "production"]
