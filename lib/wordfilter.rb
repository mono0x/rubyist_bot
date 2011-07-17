# -*- coding: utf-8 -*-

class WordFilter

  def initialize(options = {})
    @text_re = Regexp.union((options[:text] || []).map {|w| /#{w}/i}.to_a)
    @screen_name_re = /^#{Regexp.union((options[:screen_name] || []).map {|n| /#{n}/i}.to_a)}$/
  end

  def match(status)
    return false if status.text =~ @text_re
    return false if status.user.screen_name =~ @screen_name_re
    true
  end

end

