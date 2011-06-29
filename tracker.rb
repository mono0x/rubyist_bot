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
      :method => 'POST',
      :filters => @track,
      :on_inited => Proc.new { @on_inited.call if @on_inited },
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

    stream.on_reconnect do |timeout, retries|
      @on_reconnect.call timeout, retries if @on_reconnect
    end

    stream.on_close do
      @on_close.call if @on_close
    end
  end

  def on_inited(&block)
    @on_inited = block
  end

  def on_error(&block)
    @on_error = block
  end

  def on_max_reconnects(&block)
    @on_max_reconnects = block
  end

  def on_reconnect(&block)
    @on_reconnect = block
  end

  def on_close(&block)
    @on_close = block
  end

end

