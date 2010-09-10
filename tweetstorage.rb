# -*- coding: utf-8 -*-

require 'tokyotyrant'
require 'json'

class TweetStorage

  def initialize(host, port)
    @db = TokyoTyrant::RDBTBL.new
    @db.open host, port
  end

  def append(data)
    @db.put data['status']['id'].to_s, { 'status' => data['status'].to_json, 'interesting' => data['interesting'].to_s }
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
    return unless s = @db.get(id.to_s)
    { 'status' => JSON.parse(s['status']), 'interesting' => s['interesting'] != 'false' }
  end

  def search(limit, page = 0)
    q = TokyoTyrant::RDBQRY.new(@db)
    q.setlimit limit, page * limit
    q.search.map {|id| get(id) }
  end

end

