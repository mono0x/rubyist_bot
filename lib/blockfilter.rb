# -*- coding: utf-8 -*-

require 'rubytter'

class BlockFilter

  def initialize(consumer, access_token)
    @consumer = consumer
    @access_token = access_token
    @rubytter = OAuthRubytter.new(access_token)
  end

  def match(status)
    @rubytter.user status.user.id rescue return false
    true
  end

end

