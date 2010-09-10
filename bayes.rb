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

class Bayes

  def initialize(file)
    @file = file
    @bayes = if File.exist?(file)
      @loaded = true
      Marshal.load open(file)
    else
      @loaded = false
      Classifier::Bayes.new('interesting', 'uninteresting')
    end
    @wakati = MeCab::Tagger.new('-O wakati')
  end

  def save
    open(@file, 'w') do |f|
      f.flock File::LOCK_EX
      Marshal.dump @bayes, f
      f.flock File::LOCK_UN
    end
  end

  def append(text, interesting)
    t = interesting ? 'interesting' : 'uninteresting'
    @bayes.train t, parse_text(text)
  end

  def classify(text)
    @bayes.classify(parse_text(text)) == 'Interesting'
  end

  def loaded?
    @loaded
  end

  private

  def parse_text(text)
    @wakati.parse(text).force_encoding(Encoding::UTF_8)
  end

end

