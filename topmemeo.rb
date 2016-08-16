#! /usr/bin/env ruby
require 'mechanize'
require 'sequel'
require 'chatterbot/dsl'
require 'logger'

DIR = File.expand_path(File.dirname(__FILE__)) #path to containing folder
DB_PATH ="#{DIR}/memeorandum.db"
DB = Sequel.sqlite(DB_PATH)
#Twitter will shorten URLS to about 25 chars, so our tweet length needs to be slightly shorter than 140
MAX_TWEET_BASE_LENGTH = 114

class Log
  def self.log
    unless @logger
      @logger = Logger.new('topmemeo.log', 'monthly')
      @logger.level = Logger::DEBUG
      @logger.datetime_format = '%Y-%m-%d %H:%M:%S'
    end
    @logger
  end
end

#Define table if new db 
unless File.exist?(DB_PATH)
  DB.create_table :posts do 
    primary_key :id
    String :headline, :null => false
    String :author
    String :website, :null => false
    String :url, :null => false
    DateTime :created_at, :null => false
  end
  Log.log.debug "DB file not found. New DB file created"
else
  Log.log.debug "DB file detected"
end

class Post < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps
  def validate
    super
    validates_presence [:headline, :website, :url]
    validates_unique [:url, :headline], :message => "combination is not unique"
    validates_format /\Ahttps?:\/\/.*\./, :url, :message=>'is not a valid URL'
  end
end


def get_page
  Log.log.info "Starting page get"
  a = Mechanize.new
  attempts ||= 3
  begin
    page = a.get("http://www.memeorandum.com/m/")
  rescue SocketError => e
    if (attempts -= 1) > 0
      Log.log.error "Unable to load page. Retrying."
      retry
    else
      Log.log.fatal "Loading page failed"
      raise "Unable to load page: #{e.message}"
    end
  else
    Log.log.info "Page complete"
    return page
  end
end
  
def build_post(page)
  post = Post.new
  Log.log.info "Building post"
  binding.pry if defined? Pry
  post.headline = page.search("td.class","a.item")[0].children[3].text
  Log.log.debug "Headline saved"
  author_website = page.search("td.class","a.item")[0].children[1].text.gsub(/\n|:/,"")
  if author_website.include?(" / ")
    Log.log.debug "author and website detected, splitting"
    auth_site_array = author_website.split(" / ")
    post.author = auth_site_array[0]
    post.website = auth_site_array[1]
  else
    Log.log.debug "Website only detected"
    post.website = author_website
    post.author = nil
  end
  Log.log.debug "Website/author saved"
  post.url = page.search("td.class","a.item")[0].attributes["href"].text
  Log.log.debug "URL saved"
  Log.log.info "Post built"
  return post
end

def save_to_db(post)
  #TODO split validation and saving into separate methods
  if post.valid?
    post.save
    Log.log.info "New post saved to DB"
    return true
  else
    Log.log.info "Post not valid. Not saved to DB"
    post.errors.each {|x| Log.log.info x.join(" ")}
    return false
  end
end

def build_tweet(post)
  #Build the longest tweet you can below the char limit
  #TODO: Refactor this to be less horrible. Including detection for null author
  haw = "#{post.headline} | #{post.author} #{post.website}"
  hw = "#{post.headline} | #{post.website}"
  h = "#{post.headline}"
  u = " #{post.url}"
  Log.log.info "Building Tweet"
  case 
  when haw.length < MAX_TWEET_BASE_LENGTH
    tweet = haw + u 
    Log.log.info "Headline + author + website tweet built"
  when hw.length < MAX_TWEET_BASE_LENGTH
    tweet = hw + u
    Log.log.info "Headline + website tweet built"
  when h.length < MAX_TWEET_BASE_LENGTH
    tweet = h + u 
    Log.log.info "Headline only tweet built"
  else
    tweet = "#{post.headline[0..MAX_TWEET_BASE_LENGTH]} | #{u}"
    Log.log.info "Truncated headline tweet built"
  end
  return tweet
end


def send_tweet(tweet_msg)
  tweet tweet_msg 
  Log.log.info "Tweet sent"
end

def runtime
  Log.log.info "Beginning Run"
  page = get_page
  post = build_post(page)
  if save_to_db(post)
    tweet_msg = build_tweet(post)
    send_tweet(tweet_msg)
  end
  Log.log.info "Run Complete"
end

if __FILE__ == $0
  runtime
end