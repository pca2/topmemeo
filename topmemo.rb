#! /usr/bin/env ruby
require 'mechanize'
require 'sequel'
require 'chatterbot/dsl'

DIR = File.expand_path(File.dirname(__FILE__)) #path to containing folder
DB_PATH ="#{DIR}/memeorandum.db"
DB = Sequel.sqlite(DB_PATH)
#Twitter will shorten URLS to about 25 chars, so our tweet length needs to be slightly shorter than 140
MAX_TWEET_BASE_LENGTH = 114

#TODO: Wrap all this in a setup method or something
unless File.exist?(DB_PATH)
  DB.create_table :posts do 
    primary_key :id
    String :headline, :null => false
    String :author
    String :website, :null => false
    String :url, :null => false
    DateTime :created_at, :null => false
  end
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
  a = Mechanize.new
  attempts ||= 3
  begin
    page = a.get("http://www.memeorandum.com/m/")
  rescue SocketError => e
    if (attempts -= 1) > 0
      puts "Error! Unable to load page. Retrying"
      retry
    else
      raise "Unable to load page: #{e.message}"
    end
  else
    return page
  end
end
  
  
def build_post(page)
  post = Post.new
  post.headline = page.search("td.class","a.item")[0].children[3].text
  author_website = page.search("td.class","a.item")[0].children[1].text.gsub(/\n|:/,"")
  if author_website.include?(" / ")
    auth_site_array = author_website.split(" / ")
    post.author = auth_site_array[0]
    post.website = auth_site_array[1]
  else
    post.website = author_website
    post.author = nil
  end
  post.url = page.search("td.class","a.item")[0].attributes["href"].text
  return post
end

def save_to_db(post)
  if post.valid?
    post.save
    puts "New post saved to DB"
    return true
  else
    post.errors.each {|x| puts x.join(" ")}
    return false
  end
end


def build_tweet(post)
  #Build the longest tweet you can below the char limit
  #TODO: Refactor this to be less horrible.
  case 
  when "#{post.headline} |#{post.author} #{post.website}".length < MAX_TWEET_BASE_LENGTH
    tweet = "#{post.headline} |#{post.author} #{post.website} #{post.url}"
  when "#{post.headline} | #{post.website}".length < MAX_TWEET_BASE_LENGTH
    tweet = "#{post.headline} | #{post.website} #{post.url}"
  when "#{post.headline}".length < MAX_TWEET_BASE_LENGTH
    tweet = "#{post.headline} | #{post.url}"
  else
    tweet = "#{post.headline[0..MAX_TWEET_BASE_LENGTH]} | #{post.url}"
  end
  return tweet
end


def send_tweet(tweet_msg)
  #TODO: Add method
  tweet tweet_msg 
end

#run TODO: Add method
def run
  page = get_page
  post = build_post(page)
  if save_to_db(post)
    tweet_msg = build_tweet(post)
    send_tweet(tweet_msg)
  else
    puts "No new link"
  end
end

if __FILE__ == $0
  run
end

