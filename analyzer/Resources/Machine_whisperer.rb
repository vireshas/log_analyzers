require File.join(File.expand_path(File.dirname(__FILE__)),"../Resources/Stat_client.rb")
require File.join(File.expand_path(File.dirname(__FILE__)),"../Resources/Clerk.rb")

# Because it is supposed to talk to machines
class Machine_whisperer
		
	def initialize(stat_hash)
		stat_type = stat_hash["name"]
		limit = stat_hash["sleepLimit"]
		level = stat_hash["alertLevel"]
		command_set = stat_hash["commands"]
		while true
			command_set.each_index do |x|
				holder = open(command_set[x][0])
				name_arr = Clerk.name_stamp((holder.read().split("\n")),stat_type)
				holder = open(command_set[x][1])
				val_arr = holder.read().split("\n").map{|x| x.to_i}
				Statsd.gauges(name_arr,val_arr)
				if level == -1
					sleep limit
				else
					alert = false
					val_arr.each do |some_val|
						if some_val > level
							alert = true
						end
					end
					
					if alert
						sleep (limit/2).to_i
						Statsd.increment(Clerk.name_stamp(Array["Alerts"],stat_type))
					else
						sleep limit
					end
				end
			end
		end	
	end
end
