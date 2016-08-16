# Topmemeo

This script tracks the top article on political news aggregation site [memeorandum.com](http://memeorandum.com). Every time a new article makes it to the top, it's saved to a database and tweeted to [@topmemeorandum](https://twitter.com/topmemeorandum)

### Overview 

The script works by:

1. Downloading the latest version of memeorandum.com 
2. Parsing the key elements from the top post
3. Checking the database to see if the post is unique
4. If it is, saving it to the DB, and tweeting it

### Setup

1. Register a Twitter account and developer application. I used [this script](https://gist.github.com/shouya/122e67a34712999916ca) to authorize my account, but there are many other ways to do it
2. The Twitter credentials are kept in topmemeo.yml. An example file is provided with the details ommitted
3. Run `bundle install`
4. Profit!

*Note:* This project is not affiliated in any way with memeorandum.com
