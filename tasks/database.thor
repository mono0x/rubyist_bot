
require 'dm-migrations'

$LOAD_PATH.push "#{File.dirname(__FILE__)}/../lib"

require 'model'

class Database < Thor

  desc 'migrate', 'migrate the database'
  def migrate
    DataMapper.auto_migrate!
  end

  desc 'upgrade', 'upgrade the database'
  def upgrade
    DataMapper.auto_upgrade!
  end

end

