# -*- coding: utf-8 -*-

require 'classifier'
require 'MeCab'

require_relative 'workaround'

class Bayes

  def initialize(file)
    @file = file
    @bayes = if File.exist?(file)
      Marshal.load open(file)
    else
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

  private

  def parse_text(text)
    @wakati.parse text
  end

end

