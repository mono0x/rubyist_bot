# -*- coding: utf-8 -*-

class HashtagFilter

  def initialize
  end

  def match(status)
    status.text !~ /(?:^|[^\p{Word}])#\p{Word}+/
  end

end

