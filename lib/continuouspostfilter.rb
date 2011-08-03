# -*- coding: utf-8 -*-

class ContinuousPostFilter

  def initialize(options)
    @interval = options[:interval] || 30 * 60
    @expires = {}
  end

  def match(status)
    time = Time.now - @interval
    @expires.delete_if {|k, v| v < time}
    return false if @expires.include?(status.user.screen_name)
    @expires[status.user.screen_name] = Time.now
    true
  end

end

