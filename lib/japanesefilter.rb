# -*- coding: utf-8 -*-

class JapaneseFilter

  def initialize
  end
  
  def match(status)
    status.text =~ /\p{Hiragana}|\p{Katakana}/
  end

end

