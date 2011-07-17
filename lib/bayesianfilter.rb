# -*- coding: utf-8 -*-

class BayesianFilter

  def initialize(options)
    @bayesian = options[:bayesian]
  end

  def match(status)
    @bayesian.interesting? status.text
  end

end

