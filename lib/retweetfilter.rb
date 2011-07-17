# -*- coding: utf-8 -*-

class RetweetFilter

  def initialize
  end

  def match(status)
    return false if status.retweeted_status
    true
  end

end

