# -*- coding: utf-8 -*-

require 'dm-core'

DataMapper.setup :default, 'sqlite3:data/database.sqlite3'

class Status
  include DataMapper::Resource

  property :id,          Integer, :required => true, :key => true
  property :text,        String,  :required => true
 
  storage_names[:default] = 'statuses'
  default_scope(:default).update :order => [ :id.desc ]
end

