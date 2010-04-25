#!/usr/bin/ruby -Ku

require 'rubygems'
require 'webrick'
require 'net/http'
require 'uri'
require 'json'
require 'twitter'
require 'jcode'

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

CONFIG = JSON.parse(open('config.json').read)

ACCOUNT = CONFIG['account']
PASSWORD = CONFIG['password']
KEYWORD = 'ruby'

twitter = Twitter::Base.new(Twitter::HTTPAuth.new(ACCOUNT, PASSWORD))

begin
  Tracker.start(ACCOUNT, PASSWORD, KEYWORD) do |status|
    text = status['text']
    next unless text && text =~ /[ぁ-んァ-ヶ]/ && text !~ /\@#{ACCOUNT}/
    next if text =~ /\ART/
    screen_name = status['user']['screen_name']
    next if screen_name == ACCOUNT
    text = text.gsub(/([\@\#])([[:alnum:]_]+)/) {"#{$1}{#{$2}}"}
    text = text.gsub(/([^[:alnum:]_]|\A)(#{KEYWORD})([^[:alnum:]_]|\Z)/i) {
      "#{$1}#{$2.tr("A-Za-z", "Ａ-Ｚａ-ｚ")}#{$3}"
    }
    content = "RT $#{screen_name}: #{text}"
    content = content.match(/\A.{137}.../m)[0] if content.size > 140
    twitter.update content
  end
rescue
  retry
end

