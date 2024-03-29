FROM ruby:2.7.0 AS builder
ENV LANG C.UTF-8
ENV RAILS_ENV production
ENV MYSQL_DB_ADAPTER nulldb
ARG YARN_VERSION=1.13.0

# Add Yarn to the sources list
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo 'deb http://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list

RUN apt-get update && \
    apt-get install -y nodejs \
                       yarn \
                       vim \
                       default-mysql-client \
                       default-libmysqlclient-dev \
                       --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# RUN rm /usr/lib/x86_64-linux-gnu/libssl.so && ln -nfs /usr/lib/x86_64-linux-gnu/libssl.so.1.0.2 /usr/lib/x86_64-linux-gnu/libssl.so

ENV APP_ROOT /app
RUN mkdir -p $APP_ROOT
WORKDIR $APP_ROOT
ADD ./Gemfile Gemfile
ADD ./Gemfile.lock Gemfile.lock
RUN gem install bundler:2.0.1
RUN bundle install
ARG RAILS_MASTER_KEY=1
# Install yarn packages
COPY package.json yarn.lock /app/
RUN yarn install

COPY env $APP_ROOT/.env
RUN mkdir -p $APP_ROOT/tmp/pids
# Only add files that affect the assets:precompile task
ADD Rakefile                                /app/Rakefile
ADD config                 /app/config
ADD app/assets                              /app/app/assets
ADD lib/assets                              /app/lib/assets
RUN SKIP_APP_CACHE=true bundle exec rake assets:precompile

FROM madnight/docker-alpine-wkhtmltopdf as wkhtmltopdf

FROM ruby:2.7.0 as deploy
LABEL maintainer="lixiumiao@gmail.com"
ENV RAILS_ENV production
ENV LANG C.UTF-8

ENV APP_ROOT /app
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_SERVE_STATIC_FILES true
ARG YARN_VERSION=1.13.0

# Add Yarn to the sources list
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo 'deb http://dl.yarnpkg.com/debian/ stable main' > /etc/apt/sources.list.d/yarn.list

RUN apt-get update && \
    apt-get install -y nodejs \
                       yarn \
                       vim \
                       default-mysql-client \
                       default-libmysqlclient-dev \
                       --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

WORKDIR $APP_ROOT
ADD . $APP_ROOT
RUN gem install bundler -v 2.0.1 && gem install rake  -v 12.3.3  
RUN mkdir -p tmp/pids && mkdir -p log && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" >  /etc/timezone
COPY --from=wkhtmltopdf /bin/wkhtmltopdf /bin/

COPY --from=builder $GEM_HOME $GEM_HOME
COPY --from=builder $APP_ROOT $APP_ROOT

RUN date -u > BUILD_TIME

EXPOSE  3000
CMD ["rails", "server", "-b", "0.0.0.0", "-e", "production"]
