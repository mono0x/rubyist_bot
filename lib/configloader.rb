# -*- coding: utf-8 -*-

require 'json'
require 'hashie'

class ConfigLoader

  class << self

    def load
      Hashie::Mash.new JSON.parse(open('config/config.json', 'r:utf-8').read) 
    end

  end

end

