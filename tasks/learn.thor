
require 'json'
require 'hashie'

$LOAD_PATH.push "#{File.dirname(__FILE__)}/../lib"

require 'model'
require 'bayesian'

class Learn < Thor

  desc 'status', 'learn a status'
  def status(id, switch)
    unless status = Status.first(:id => id)
      return
    end
    if (flag = switch_to_boolean(switch)).nil?
      return
    end
      
    bayesian = Bayesian.new(:path => 'data/bayesian.dat')
    bayesian.learn status.text, flag
    bayesian.save
    status.destroy
  end

  desc 'search', 'learn statues'
  def search(query = nil)
    bayesian = Bayesian.new(:path => 'data/bayesian.dat')

    Signal.trap :INT do
      bayesian.save
      exit
    end

    statuses = Status.all
    statuses &= query.split(' ').map {|q| Status.all(:text => "%#{q}%")}.inject(&:&) if query
    statuses.each do |status|
      STDERR.puts status.text
      flag = nil
      loop do
        STDERR.print '> '
        flag = switch_to_boolean(STDIN.gets)
        break unless flag.nil?
      end
      bayesian.learn status.text, flag
      status.destroy
    end
    bayesian.save
  end

  private

  def switch_to_boolean(switch)
    case switch
    when /^(?:true|t|on|yes|y)$/i
      true
    when /^(?:false|f|off|no|n)$/i
      false
    else
      nil
    end
  end

end

