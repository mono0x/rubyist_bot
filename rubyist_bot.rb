#!/usr/bin/ruby -Ku
# coding: utf-8

require 'logger'
require 'uri'
require 'json'
require 'eventmachine'
require 'em-http'
require 'oauth'
require 'oauth/client/em_http'

require_relative 'workaround'
require_relative 'tweetstorage'
require_relative 'bayes'
require_relative 'tracker'
require_relative 'similarityfilter'

log = Logger.new(STDERR)

CONFIG = JSON.parse(open('config.json', 'r:utf-8').read)

ACCOUNT = CONFIG['account']
PASSWORD = CONFIG['password']
CONSUMER_TOKEN = CONFIG['consumer_token']
CONSUMER_SECRET = CONFIG['consumer_secret']
ACCESS_TOKEN = CONFIG['access_token']
ACCESS_SECRET = CONFIG['access_secret']
TOKYO_TYRANT = CONFIG['tokyo_tyrant']
BLOCK_LENGTH = CONFIG['block']['length']
BLOCK_SIMILARITY_SAMPLES = CONFIG['block']['similarity']['samples']
BLOCK_SIMILARITY_THRESHOLD = CONFIG['block']['similarity']['threshold']
BLOCK_WORDS = CONFIG['block']['word']
BLOCK_NAMES = CONFIG['block']['screen_name']
KEYWORDS = CONFIG['keywords']

consumer = OAuth::Consumer.new(CONSUMER_TOKEN, CONSUMER_SECRET)
access_token = OAuth::AccessToken.new(consumer, ACCESS_TOKEN, ACCESS_SECRET)

similarity_filter = SimilarityFilter.new(KEYWORDS, BLOCK_SIMILARITY_SAMPLES, BLOCK_SIMILARITY_THRESHOLD)

storage = TweetStorage.new(TOKYO_TYRANT['host'], TOKYO_TYRANT['port'])

bayes = Bayes.new('bayes.dat')

begin
  EventMachine.run do
    tracker = Tracker.new(CONSUMER_TOKEN, CONSUMER_SECRET, ACCESS_TOKEN, ACCESS_SECRET, KEYWORDS)
    tracker.start do |status|
      text = status['text']
      next unless text && text =~ /\p{Hiragana}|\p{Katakana}/ && text !~ /\@#{ACCOUNT}/
      next if text =~ /#\w+/
      next if text.match(/\A(.*?)(?:[RQ]T|\z)/)[1].size < BLOCK_LENGTH
      next if BLOCK_WORDS.any?{|w| text[w]}
      screen_name = status['user']['screen_name']
      next if screen_name == ACCOUNT
      next if BLOCK_NAMES.any?{|n| screen_name[n]}
      next unless similarity_filter.update(text)

      storage.append status

      if bayes.loaded?
        log.info status['text']
        next unless bayes.classify(status['text'])
      end

      req = EventMachine::HttpRequest.new('http://api.twitter.com/1/users/show.json')
      http = req.get(:query => { 'user_id' => status['user']['id'] }) do |client|
        consumer.sign! client, access_token
      end
      http.callback do
        if http.response_header.status == 200
          uri = "http://api.twitter.com/1/statuses/retweet/#{status['id']}.json"
          http = EventMachine::HttpRequest.new(uri).post(:head => { 'Content-Type' => 'application/x-www-form-urlencoded' }) do |client|
            consumer.sign! client, access_token
          end
        end
      end
    end
    tracker.on_error do |m|
      log.info m
      EventMachine.stop if EventMachine.reactor_running?
    end
    tracker.on_max_reconnects do |timeout, retries|
      log.info "max reconnects #{timeout} : #{retries}"
      EventMachine.stop if EventMachine.reactor_running?
    end
  end
rescue
  log.error $!
  retry
end

