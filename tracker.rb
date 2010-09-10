# -*- coding: utf-8 -*-

require 'json'
require 'twitter/json_stream'

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

