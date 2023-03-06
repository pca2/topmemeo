FROM alpine:3.17

ENV BUILD_PACKAGES bash curl curl-dev ruby-dev build-base
ENV RUBY_PACKAGES \
  ruby ruby-io-console ruby-irb \
  ruby-json ruby-etc ruby-bigdecimal ruby-rdoc \
  libffi-dev zlib-dev
ENV TERM=linux
ENV PS1 "\n\n>> ruby \W \$ "

RUN apk --no-cache add $BUILD_PACKAGES $RUBY_PACKAGES


WORKDIR /usr/src/app
COPY Gemfile Gemfile.lock ./
ENV BUNDLE_FROZEN=true
RUN gem install bundler && bundle config set --local without 'dev'
RUN echo 'gem: --no-document' > /etc/gemrc
RUN bundle config --global silence_root_warning 1

# Copy local code to the container image.
RUN bundle install

# Copy function code
COPY app.rb .
COPY toot.rb .
COPY get_quotes.rb .
# Must match configuration in lambda
ENV PORT=8080
EXPOSE $PORT
CMD ["functions-framework-ruby", "--target","runtime", "-s","app.rb"]
