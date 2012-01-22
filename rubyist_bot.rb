# -*- coding: utf-8 -*-

require 'json'
require 'hashie'
require 'bitly'

Bitly.use_api_version_3

$LOAD_PATH.push "#{File.dirname(__FILE__)}/lib"

require 'configloader'
require 'stream'
require 'statuslogger'

require 'bayesian'
require 'bayesianfilter'
require 'blockfilter'
require 'continuouspostfilter'
require 'hashtagfilter'
require 'hastextfilter'
require 'japanesefilter'
require 'lengthfilter'
require 'retweetfilter'
require 'similarityfilter'
require 'wordfilter'

require 'statusgenerator'

class RubyistBot

  def initialize
    reload_config
  end

  def reload_config
    @config = ConfigLoader.load
    @bayesian = Bayesian.new(:path => 'data/bayesian.dat')

    @consumer = OAuth::Consumer.new(
      @config.consumer_token,
      @config.consumer_secret,
      :site => 'https://api.twitter.com')

    @access_token = OAuth::AccessToken.new(
      @consumer,
      @config.access_token,
      @config.access_secret)

    @stream_consumer = OAuth::Consumer.new(
      @config.consumer_token,
      @config.consumer_secret,
      :site => 'https://stream.twitter.com')

    @stream_access_token = OAuth::AccessToken.new(
      @stream_consumer,
      @config.access_token,
      @config.access_secret)

    @filters = [
      HasTextFilter.new,
      RetweetFilter.new,
      JapaneseFilter.new,
      HashtagFilter.new,
      LengthFilter.new(:length => @config.block.text_length),
      WordFilter.new(:text => @config.block.word, :screen_name => @config.block.screen_name),
      SimilarityFilter.new(:keywords => @config.keywords, :sample_count => @config.block.similarity.sample_count, :threshold => @config.block.similarity.threshold),
      StatusLogger.new,
      BayesianFilter.new(:bayesian => @bayesian),
      ContinuousPostFilter.new(:interval => @config.block.continuous_interval),
      BlockFilter.new(@consumer, @access_token),
    ]

    @rubytter = OAuthRubytter.new(@access_token)

    @bitly = Bitly::V3::Client.new(@config.bitly.account, @config.bitly.api_key)

    @generator = StatusGenerator.new(:bitly => @bitly)
  end

  def run
    Signal.trap :HUP do
      reload_config
    end

    Stream.new(@stream_consumer, @stream_access_token).filter(@config.keywords) do |status|
      next unless @filters.all? {|f| f.match status }
      @rubytter.update @generator.generate(status)
    end
  end

end

RubyistBot.new.run

