# -*- coding: utf-8 -*-

class StatusGenerator

  def initialize(options)
    @bitly = options[:bitly]
  end

  def generate(status)
    url = @bitly.shorten("https://twitter.com/#{status.user.screen_name}/status/#{status.id}")
    footer = " via #{url.short_url}"
    text = status.text.gsub(%r!@(\w+)!) { "#$1" }
    "#{(text.size > (140 - footer.size) ? "#{text[0, max_size - 3]}..." : text)}#{footer}"
  end

end

