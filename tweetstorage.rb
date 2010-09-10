# -*- coding: utf-8 -*-

require 'tokyotyrant'
require 'json'

class TweetStorage

  def initialize(host, port)
    @db = TokyoTyrant::RDBTBL.new
    @db.open host, port
  end

  def append(status)
    @db.put status['id'].to_s, { 'status' => status.to_json }
  end

  def remove(id)
    @db.delete id.to_s
  end

  def get(id = nil)
    unless id
      q = TokyoTyrant::RDBQRY.new(@db)
      q.setlimit 1
      id = q.search[0]
    end
    s = @db.get(id.to_s)
    s ? JSON.parse(s['status']) : nil
  end

  def size
    q = TokyoTyrant::RDBQRY.new(@db)
    q.searchcount
  end

end

