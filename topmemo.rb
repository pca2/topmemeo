require 'mechanize'
a = Mechanize.new
page = a.get("http://www.memeorandom.com/m")
body = page.search("td.class","a.item")[0].children[3].text
author = page.search("td.class","a.item")[0].children[1].text.gsub(/\n|:/,"")
url = page.search("td.class","a.item")[0].attributes["href"].text
body + author + url
tweet = "#{body} | #{author} #{url}"