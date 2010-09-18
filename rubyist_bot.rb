#!/usr/bin/ruby -Ku
# coding: utf-8

require 'uri'
require 'json'
require 'eventmachine'
require 'em-http'
require 'oauth'
require 'oauth/client/em_http'
require 'sinatra/base'
require 'sinatra/async'
require 'erubis'
require 'logger'

require_relative 'workaround'
require_relative 'tweetstorage'
require_relative 'bayes'
require_relative 'tracker'
require_relative 'similarityfilter'

class RubyistBotApplication < Sinatra::Base
  register Sinatra::Async

  set :sessions, true
  set :logging, false
  set :views, "#{File.dirname(__FILE__)}/view"

  configure do

    @@logger = Logger.new(STDERR)
    use Rack::CommonLogger, STDERR

    @@config = JSON.parse(open('config.json', 'r:utf-8').read)

    use Rack::Auth::Basic do |account, password|
      basic_auth = @@config['basic_auth']
      account == basic_auth['account'] && password == basic_auth['password']
    end

    @@consumer = OAuth::Consumer.new(@@config['consumer_token'], @@config['consumer_secret'])
    @@access_token = OAuth::AccessToken.new(@@consumer, @@config['access_token'], @@config['access_secret'])

    block = @@config['block']

    @@similarity_filter = SimilarityFilter.new(@@config['keywords'], block['similarity']['samples'], block['similarity']['threshold'])

    @@storage = TweetStorage.new(@@config['tokyo_tyrant']['host'], @@config['tokyo_tyrant']['port'])

    @@bayes = Bayes.new('bayes.dat')

    EventMachine.schedule do
      tracker = Tracker.new(@@config['consumer_token'], @@config['consumer_secret'], @@config['access_token'], @@config['access_secret'], @@config['keywords'])
      tracker.start do |status|
        text = status['text']
        next unless text && text =~ /\p{Hiragana}|\p{Katakana}/ && text !~ /\@#{@@config['account']}/
        next if text =~ /#\w+/
        next if text.match(/\A(.*?)(?:[RQ]T|\z)/m)[1].size < block['length']
        next if block['word'].any?{|w| text[w]}
        screen_name = status['user']['screen_name']
        next if screen_name == @@config['account']
        next if block['screen_name'].any?{|n| screen_name[n]}
        next unless @@similarity_filter.update(text)

        interesting = @@bayes.classify(status['text'])
        @@storage.append({ 'status' => status, 'interesting' => interesting })
        next unless interesting

        req = EventMachine::HttpRequest.new('http://api.twitter.com/1/users/show.json')
        http = req.get(:query => { 'user_id' => status['user']['id'] }) do |client|
          @@consumer.sign! client, @@access_token
        end
        http.callback do
          if http.response_header.status == 200
            uri = "http://api.twitter.com/1/statuses/retweet/#{status['id']}.json"
            http = EventMachine::HttpRequest.new(uri).post(:head => { 'Content-Type' => 'application/x-www-form-urlencoded' }) do |client|
              @@consumer.sign! client, @@access_token
            end
          end
        end
      end
      tracker.on_error do |m|
        @@logger.info m
        EventMachine.stop_event_loop if EventMachine.reactor_running?
      end
      tracker.on_max_reconnects do |timeout, retries|
        @@logger.info "max reconnects #{timeout} : #{retries}"
        EventMachine.stop_event_loop if EventMachine.reactor_running?
      end
    end

  end

  get '/' do
    erubis :index, :locals => {
      :tweets => @@storage.search(20),
    }
  end

  post '/submit' do
    if params['tweet']
      params['tweet'].each do |id, data|
        tweet = @@storage.get(id)
        @@bayes.append tweet['status']['text'], data['checked'] == 'true'
        @@storage.remove id
      end
      @@bayes.save
    end
    redirect '/'
  end

  get '/restart' do
    EventMachine.stop_event_loop
  end

end

