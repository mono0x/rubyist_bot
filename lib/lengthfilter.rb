# -*- coding: utf-8 -*-

class LengthFilter

  def initialize(options = {})
    @length = options[:length] || 30
  end

  def match(status)
    status.text.match(/^(.*?)(?:[RQ]T.*)?$/m)[1].size >= @length
  end

end

