# -*- coding: utf-8 -*-

require 'classifier'
require 'json'
require 'MeCab'

require_relative 'tweetstorage'
require_relative 'bayes'

config = JSON.parse(open('config.json', 'r:utf-8').read)

tt = config['tokyo_tyrant']
storage = TweetStorage.new(tt['host'], tt['port'])

bayes = Bayes.new('bayes.dat')

loop do
  size = storage.size
  break unless size > 0
  puts "size: #{storage.size}"
  print 'status.id>'
  id = gets.to_i
  status = storage.get(id > 0 ? id : nil)
  break unless status
  puts status['text']
  print 'interesting>'
  bayes.append status['text'], gets.to_i != 0
  storage.remove status['id']
end

bayes.save

