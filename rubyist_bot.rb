#!/usr/bin/ruby -Ku
# coding: utf-8

require 'logger'
require 'uri'
require 'json'
require 'eventmachine'
require 'em-http'
require 'oauth'
require 'oauth/client/em_http'
require 'twitter/json_stream'

require_relative 'workaround'
require_relative 'tweetstorage'
require_relative 'bayes'

class Tracker

  def initialize(consumer_token, consumer_secret, access_token, access_secret, track)
    @consumer_token = consumer_token
    @consumer_secret = consumer_secret
    @access_token = access_token
    @access_secret = access_secret
    @track = track
  end

  def start(&block)
    stream = Twitter::JSONStream.connect(
      :filters => @track,
      :oauth => {
        :consumer_key => @consumer_token,
        :consumer_secret => @consumer_secret,
        :access_key => @access_token,
        :access_secret => @access_secret,
      })

    stream.each_item do |item|
      block.call JSON.parse(item)
    end

    stream.on_error do |m|
      @on_error.call m if @on_error
    end

    stream.on_max_reconnects do |timeout, retries|
      @on_max_reconnects.call timeout, retries if @on_max_reconnects
    end
  end

  def on_error(&block)
    @on_error = block
  end

  def on_max_reconnects(&block)
    @on_max_reconnects = block
  end

end

def levenshtein_distance(lhs, rhs)
  width = lhs.size + 1
  height = rhs.size + 1
  d = Array.new(width * height, 0)

  width.times do |i|
    d[i] = i
  end
  height.times do |i|
    d[i * width] = i
  end

  1.upto(height - 1) do |y|
    1.upto(width - 1) do |x|
      cost = lhs[x - 1] == rhs[y - 1] ? 0 : 1
      i = x + y * width
      d[x + y * width] = [
        d[i - 1] + 1,
        d[i - width] + 1,
        d[i - (width + 1)] + cost,
      ].min
    end
  end
  d.last
end

def remove_uri(src)
  src.gsub %r!https?://.+?(?:/|$|\s|[^\w])!, ''
end

def similarity(lhs, rhs)
  max = [lhs.size, rhs.size].max
  max > 0 ? 1.0 - levenshtein_distance(lhs, rhs).to_f / max : 1.0
end

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

KEYWORDS_RE = Regexp.union(KEYWORDS.map{|k| /#{k}/i})

consumer = OAuth::Consumer.new(CONSUMER_TOKEN, CONSUMER_SECRET)
access_token = OAuth::AccessToken.new(consumer, ACCESS_TOKEN, ACCESS_SECRET)

samples = []

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
      text_without_uri = remove_uri(text).tr('A-Z', 'a-z').gsub(KEYWORDS_RE, '')
      next if samples.any? {|t|
        similarity(t, text_without_uri) > BLOCK_SIMILARITY_THRESHOLD
      }
      samples.shift if samples.size >= BLOCK_SIMILARITY_SAMPLES
      samples.push text_without_uri

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

