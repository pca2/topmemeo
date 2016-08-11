#! /usr/bin/env ruby

require 'mechanize'
require 'sequel'

$:.unshift File.expand_path(File.dirname(__FILE__)) #add containing folder to load path
DIR = File.expand_path(File.dirname(__FILE__)) #path to containing folder
db_path ="#{DIR}/memeorandum.db"
DB = Sequel.sqlite(db_path)

unless File.exist?(db_path)
  DB.create_table :posts do 
    primary_key :id
    String :headline, :null => false
    String :author
    String :website, :null => false
    String :url, :null => false
    DateTime :created_at, :null => false
  end
end
Sequel::Model.plugin :timestamps

class Post < Sequel::Model
  plugin :validation_helpers
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
    binding.pry if defined? Pry
    post.errors.each {|x| puts x.join(" ")}
    return false
  end
end



page = get_page
post = build_post(page)
if save_to_db(post)
  build_tweet(post)
end



def shorten_tweet(post.url)
end



def build_tweet(post)

end


def send_tweet(tweet)
  #TODO: Add method
end


tweet = "#{post.headline} | #{post.author} #{post.website}  #{post.url}"
puts tweet
