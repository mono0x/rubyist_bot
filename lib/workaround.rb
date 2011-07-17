# -*- coding: utf-8 -*-

require 'classifier'
require 'MeCab'

class String
  private

  def word_hash_for_words(words)
    d = {}
    words.each do |word|
      word.downcase! if word =~ /[\w]+/
      key = word.stem.force_encoding(Encoding::UTF_8)
      if word =~ /[^\w]/ || !CORPUS_SKIP_WORDS.include?(word) && word.length > 2
        d[key] ||= 0
        d[key] += 1
      end
    end
    d
  end
end

class MeCab::Tagger
  alias_method :parse_, :parse
  def parse(text)
    parse_(text).force_encoding(Encoding::UTF_8)
  end
end

