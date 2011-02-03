#!/usr/bin/env rackup -s thin
# -*- coding: utf-8 -*-

require 'bundler/setup'

require 'rack'

require './rubyist_bot'

run RubyistBotApplication.new
