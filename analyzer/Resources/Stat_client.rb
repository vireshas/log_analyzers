require 'socket'
require 'yaml'

# Will pick up ./statsd.yml
# ./statsd.yml should look like:
# host: localhost
# port: 8125

# If neither of these files are present, it will default to localhost:8125

# Sends statistics to the stats daemon over UDP

class Statsd

  def self.timing(stats, time, sample_rate=1)
    Statsd.update_stats(stats, time, sample_rate, 'ms')
  end

	def self.check_rate(stats, value, sample_rate=1)
		Statsd.update_stats(stats, value, sample_rate, 'c')
	end

  def self.increment(stats, sample_rate=1)
    Statsd.update_stats(stats, 1, sample_rate, 'c')
		Statsd.update_stats(stats, 1, sample_rate, 'sig')
  end

	def self.aggregate(stats, sample_rate=1)
		Statsd.update_stats(stats, 1, sample_rate, 'sig')
	end

	def self.reduce(stats, sample_rate=1)
		Statsd.update_stats(stats, -1, sample_rate, 'sig')
	end

  def self.decrement(stats, sample_rate=1)
    Statsd.update_stats(stats, -1, sample_rate, 'c')
		Statsd.update_stats(stats, -1, sample_rate, 'sig')
  end

  def self.gauges(stats, value, sample_rate=1)
    Statsd.update_stats(stats, value, sample_rate, 'g')
  end

	def self.sigmas(stats, value, sample_rate=1)
		Statsd.update_stats(stats, value, sample_rate, 'sig')
	end

  def self.sets(stats, value, sample_rate=1)
    Statsd.update_stats(stats, value, sample_rate, 's')
  end

  def self.update_stats(stats, delta=1, sample_rate=1, metric='sig')
    stats = [stats].flatten
		delta = [delta].flatten

    data = {}
    stats.each_index do |x|
      data[stats[x]] = "%s|%s" % [delta[x], metric]
    end

    Statsd.send(data, sample_rate)
  end

  def self.send(data, sample_rate=1)
    begin
      host = config["host"] || "localhost"
      port = config["port"] || "8125"

      sampled_data = {}
      if sample_rate < 1
        if rand <= sample_rate
          data.each_pair do |stat, val|
            sampled_data[stat] = "%s|@%s" % [val, sample_rate]
          end
        end
      else
        sampled_data = data
      end

      udp = UDPSocket.new
      sampled_data.each_pair do |stat, val|
        send_data = "%s:%s" % [stat, val]
        udp.send send_data, 0, host, port
      end
    rescue => e
      puts e.message
    end
  end

  def self.config
    return @@config if self.class_variable_defined?(:@@config)
    begin
      config_path = File.join(File.dirname(__FILE__), "statsd.yml")
      @@config = open(config_path) { |f| YAML.load(f) }
    rescue => e
      puts "config: #{e.message}"
      @@config = {}
    end

    @@config
  end
end
