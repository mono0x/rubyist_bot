#!/usr/bin/ruby -Ku
# coding: utf-8

require 'webrick'
require 'net/http'
require 'uri'
require 'json'
require 'twitter'

class Tracker

  TRACK_URI = URI.parse('http://stream.twitter.com/1/statuses/filter.json')

  attr_accessor :account, :password, :track

  def initialize(account, password, track)
    @account = account
    @password = password
    @track = track
  end

  def start(&block)
    Net::HTTP.start(TRACK_URI.host, TRACK_URI.port) do |http|
      request = Net::HTTP::Post.new(TRACK_URI.request_uri)
      request.set_form_data 'track' => @track
      request.basic_auth @account, @password
      http.request(request) do |response|
        raise 'Response is not chuncked' unless response.chunked?
        response.read_body do |chunk|
          block.call JSON.parse(chunk) rescue next
        end
      end
    end
  end

  class << self
    def start(account, password, track, &block)
      Tracker.new(account, password, track).start &block
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

KEYWORD = 'ruby'

oauth = Twitter::OAuth.new(CONSUMER_TOKEN, CONSUMER_SECRET)
oauth.authorize_from_access ACCESS_TOKEN, ACCESS_SECRET
twitter = Twitter::Base.new(oauth)

samples = []

begin
  Tracker.start(ACCOUNT, PASSWORD, KEYWORD) do |status|
    text = status['text']
    next unless text && text =~ /\p{Hiragana}|\p{Katakana}/ && text !~ /\@#{ACCOUNT}/
    next if text =~ /\ART/
    next if BLOCK_WORDS.any?{|w| text[w]}
    screen_name = status['user']['screen_name']
    next if screen_name == ACCOUNT
    next if BLOCK_NAMES.any?{|n| screen_name[n]}
    text_without_uri = remove_uri(text).tr('A-Z', 'a-z').gsub(KEYWORD, '')
    next if samples.any? {|t|
      similarity(t, text_without_uri) > BLOCK_SIMILARITY_THRESHOLD
    }
    samples.shift if samples.size >= BLOCK_SIMILARITY_SAMPLES 
    samples.push text_without_uri
    text = text.gsub(/([\@\#])(\w+)/) {"#{$1}{#{$2}}"}
    text = text.gsub(/(?<=^|[^\w])(#{KEYWORD})(?=$|[^\w])/i) {
      $1.tr("A-Za-z", "Ａ-Ｚａ-ｚ")
    }
    content = "RT $#{screen_name}: #{text}"
    content = "#{content.match(/\A.{137}/m)[0]}..." if content.size > 140
    twitter.update content
  end
rescue
  retry
end

