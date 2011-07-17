# -*- coding: utf-8 -*-

require 'classifier'
require 'MeCab'

require_relative 'workaround'

class Bayesian

  def initialize(options = {})
    @path = options[:path]
    if File.exist?(@path)
      @classifier = Marshal.load(open(@path))
    else
      @classifier = Classifier::Bayes.new('Interesting', 'Uninteresting')
    end
    @tagger = MeCab::Tagger.new('-O wakati')
  end

  def save
    open(@path, 'w') do |f|
      f.flock File::LOCK_EX
      Marshal.dump @classifier, f
      f.flock File::LOCK_UN
    end
  end

  def interesting?(text)
    @classifier.classify(@tagger.parse(text)) == 'Interesting'
  end

  def learn(text, interest)
    @classifier.train interest ? 'Interesting' : 'Uninteresting', text
  end

end

