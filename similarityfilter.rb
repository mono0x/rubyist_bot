# -*- coding: utf-8 -*-

class SimilarityFilter

  def initialize(keywords, sample_count, threshold)
    @keywords_re = Regexp.union(keywords.map{|k| /#{k}/i})
    @samples = []
    @sample_count = sample_count
    @threshold = threshold
  end

  def update(text)
    text_without_uri = self.class.remove_uri(text).tr('A-Z', 'a-z').gsub(@keywords_re, '')
    return false if @samples.any? {|t|
      self.class.similarity(t, text_without_uri) > @threshold
    }
    @samples.shift if @samples.size >= @sample_count
    @samples.push text_without_uri
    true
  end

  class << self

    def remove_uri(src)
      src.gsub %r!https?://.+?(?:/|$|\s|[^\w])!, ''
    end

    def similarity(lhs, rhs)
      max = [lhs.size, rhs.size].max
      max > 0 ? 1.0 - levenshtein_distance(lhs, rhs).to_f / max : 1.0
    end

    private

    def levenshtein_distance(lhs, rhs)
      width = lhs.size + 1
      height = rhs.size + 1
      d = Array.new(width * height, 0)

      width.times do |i|
        d[i] = i
      end
      height.times do |i|
        d[i * width] = i
      end

      1.upto(height - 1) do |y|
        1.upto(width - 1) do |x|
          cost = lhs[x - 1] == rhs[y - 1] ? 0 : 1
          i = x + y * width
          d[x + y * width] = [
            d[i - 1] + 1,
            d[i - width] + 1,
            d[i - (width + 1)] + cost,
          ].min
        end
      end
      d.last
    end

  end

end

