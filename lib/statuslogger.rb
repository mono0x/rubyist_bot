# -*- coding: utf-8 -*-

require 'model'

class StatusLogger

  def initialize
  end

  def match(status)
    Status.create :id => status.id, :text => status.text
    true
  end

end

