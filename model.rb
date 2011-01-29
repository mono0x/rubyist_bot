# -*- coding: utf-8 -*-

require 'json'
require 'dm-core'

DataMapper.setup :default, 'sqlite3:statuses.sqlite3'

class Status
  include DataMapper::Resource

  property :id,          Integer, :required => true, :key => true
  property :text,        String,  :required => true
  property :interesting, Boolean, :required => true
  
  storage_names[:default] = 'statuses'
  default_scope(:default).update :order => [ :id.desc ]
end

