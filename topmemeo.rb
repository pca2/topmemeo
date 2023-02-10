#! /usr/bin/env ruby
# frozen_string_literal: true

require 'mechanize'
require 'sequel'
require 'chatterbot/dsl'
require 'logger'

DIR = __dir__ # path to containing folder
DB_PATH = "#{DIR}/memeorandum.db".freeze
DB = Sequel.sqlite(DB_PATH)
# Twitter will shorten URLS to about 25 chars, so our tweet length needs to be slightly shorter than 140
MAX_TWEET_BASE_LENGTH = 114

class Log
  def self.log
    unless @logger
      # @logger = Logger.new('/var/log/topmemeo.log', 'monthly')
      @logger = Logger.new($stdout)
      @logger.level = Logger::INFO
      @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
    end
    @logger
  end
end

# Define table if new db
# TODO save finished tweet to DB
if File.exist?(DB_PATH)
  Log.log.debug 'DB file detected'
else
  DB.create_table :posts do
    primary_key :id
    String :headline, null: false
    String :author
    String :website, null: false
    String :url, null: false
    DateTime :created_at, null: false
  end
  Log.log.debug 'DB file not found. New DB file created'
end

class Post < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps
  def validate
    super
    validates_presence %i[headline website url]
    validates_format(%r{\Ahttps?://.*\.}, :url, message: 'is not a valid URL')
    validates_unique %i[url headline], message: 'combination is not unique'
  end
end

def get_page
  Log.log.info 'Starting page get'
  a = Mechanize.new
  attempts ||= 3
  begin
    page = a.get('http://www.memeorandum.com/m/')
  rescue SocketError => e
    if (attempts -= 1).positive?
      Log.log.error 'Unable to load page. Retrying.'
      retry
    else
      Log.log.fatal 'Loading page failed'
      raise "Unable to load page: #{e.message}"
    end
  else
    Log.log.info 'Page complete'
    page
  end
end

def build_post(page)
  post = Post.new
  Log.log.info 'Building post'
  post.headline = page.search('td.class', 'a.item')[0].children[3].text
  Log.log.debug 'Headline saved'
  author_website = page.search('td.class', 'a.item')[0].children[1].text.gsub(/\n|:/, '')
  if author_website.include?(' / ')
    Log.log.debug 'author and website detected, splitting'
    auth_site_array = author_website.split(' / ')
    post.author = auth_site_array[0]
    post.website = auth_site_array[1]
  else
    Log.log.debug 'Website only detected'
    post.website = author_website
    post.author = nil
  end
  Log.log.debug 'Website/author saved'
  post.url = page.search('td.class', 'a.item')[0].attributes['href'].text
  Log.log.debug 'URL saved'
  Log.log.info 'Post built'
  post
end

def save_to_db(post)
  if post.valid?
    post.save
    Log.log.info 'New post saved to DB'
    true
  else
    post.errors.each { |x| Log.log.info x.join(' ') }
    Log.log.info 'Not saving to DB'
    false
  end
end

def build_tweet(post)
  # Build the longest tweet you can below the char limit
  # TODO: Refactor this to be less horrible. Including detection for null author
  haw = "#{post.headline} | #{post.author} #{post.website}"
  hw = "#{post.headline} | #{post.website}"
  h = post.headline.to_s
  u = " #{post.url}"
  Log.log.info 'Building Tweet'
  if haw.length < MAX_TWEET_BASE_LENGTH
    tweet = haw + u
    Log.log.info 'Headline + author + website tweet built'
  elsif hw.length < MAX_TWEET_BASE_LENGTH
    tweet = hw + u
    Log.log.info 'Headline + website tweet built'
  elsif h.length < MAX_TWEET_BASE_LENGTH
    tweet = h + u
    Log.log.info 'Headline only tweet built'
  else
    tweet = "#{post.headline[0..MAX_TWEET_BASE_LENGTH]} | #{u}"
    Log.log.info 'Truncated headline tweet built'
  end
  tweet
end

def send_tweet(tweet_msg)
  tweet tweet_msg
  Log.log.info 'Tweet sent'
  Log.log.debug tweet_msg
end

def runtime
  Log.log.info 'Beginning Run'
  page = get_page
  post = build_post(page)
  if save_to_db(post)
    tweet_msg = build_tweet(post)
    send_tweet(tweet_msg)
  end
  Log.log.info 'Run Complete'
end

runtime if __FILE__ == $PROGRAM_NAME
