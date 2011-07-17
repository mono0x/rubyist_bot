# -*- coding: utf-8 -*-

require_relative 'similarity'

class SimilarityFilter

  def initialize(options = {})
    @keywords_re = Regexp.union((options[:keywords] || []).map {|k| /#{k}/i})
    @samples = []
    @sample_count = options[:sample_count] || 500
    @threshold = options[:threshold] || 0.5
  end

  def match(status)
    text = status.text.tr('A-Z', 'a-z').gsub(@keywords_re, '')
    return false if @samples.any? {|t| Similarity.similarity(text, t) > @threshold }
    @samples.shift if @samples.size >= @sample_count
    @samples.push text
    true
  end

end

