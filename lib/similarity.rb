# -*- coding: utf-8 -*-

class Similarity

  class << self

    def similarity(lhs, rhs)
      max = [lhs.size, rhs.size].max
      max > 0 ? 1.0 - levenshtein_distance(lhs, rhs).to_f / max : 1.0
    end

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

