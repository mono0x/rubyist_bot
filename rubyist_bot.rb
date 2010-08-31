#!/usr/bin/ruby -Ku
# coding: utf-8

require 'logger'
require 'net/http'
require 'uri'
require 'json'
require 'twitter'
require 'open-uri'
require 'oauth'
require 'oauth/client/net_http'

class Tracker

  TRACK_URI = URI.parse('http://stream.twitter.com/1/statuses/filter.json')

  attr_accessor :consumer, :access_token, :track, :log

  def initialize(consumer, access_token, track, log = nil)
    @consumer = consumer
    @access_token = access_token
    @track = track
    @log = log
  end

  def start(&block)
    Net::HTTP.start(TRACK_URI.host, TRACK_URI.port) do |http|
      request = Net::HTTP::Post.new(TRACK_URI.request_uri)
      request.set_form_data 'track' => @track
      request.oauth! http, @consumer, @access_token
      http.request(request) do |response|
        raise 'Response is not chuncked' unless response.chunked?
        response.read_body do |chunk|
          begin
            block.call JSON.parse(chunk)
          rescue JSON::ParserError
          rescue
            @log.error $! if @log
          end
        end
      end
    end
  end

  class << self
    def start(consumer, access_token, track, log, &block)
      Tracker.new(consumer, access_token, track, log).start(&block)
    end
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
  src.gsub URI.regexp(['http', 'https']), ''
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
BLOCK_SIMILARITY_SAMPLES = CONFIG['block']['similarity']['samples']
BLOCK_SIMILARITY_THRESHOLD = CONFIG['block']['similarity']['threshold']
BLOCK_WORDS = CONFIG['block']['word']
BLOCK_NAMES = CONFIG['block']['screen_name']
KEYWORDS = CONFIG['keywords']

KEYWORDS_RE = Regexp.union(KEYWORDS.map{|k| /#{k}/i})

oauth = Twitter::OAuth.new(CONSUMER_TOKEN, CONSUMER_SECRET)
oauth.authorize_from_access ACCESS_TOKEN, ACCESS_SECRET
twitter = Twitter::Base.new(oauth)

consumer = OAuth::Consumer.new(CONSUMER_TOKEN, CONSUMER_SECRET)
access_token = OAuth::AccessToken.new(consumer, ACCESS_TOKEN, ACCESS_SECRET)

samples = []

begin
  Tracker.start(consumer, access_token, KEYWORDS.join(','), log) do |status|
    text = status['text']
    next unless text && text =~ /\p{Hiragana}|\p{Katakana}/ && text !~ /\@#{ACCOUNT}/
    next if text =~ /\ART/
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
    begin
      twitter.retweet status['id']
    rescue Twitter::General
    end
  end
rescue
  log.error $!
  retry
end

