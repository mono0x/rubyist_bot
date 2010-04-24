#!/usr/bin/ruby -Ku

require 'rubygems'
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

CONFIG = JSON.parse(open('config.json').read)

ACCOUNT = CONFIG['account']
PASSWORD = CONFIG['password']

twitter = Twitter::Base.new(Twitter::HTTPAuth.new(ACCOUNT, PASSWORD))

begin
  Tracker.start(ACCOUNT, PASSWORD, 'ruby') do |status|
    id=status['id']
    twitter.retweet(id)
  end
rescue 
  retry
end

