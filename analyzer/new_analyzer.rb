if ARGV[0] == "Spaghetti"
	File.open('pids/rails-spaghetti.pid', 'w') { |file| file.write(Process.pid) }
elsif ARGV[0] == "Zorro"
	File.open('pids/rails-zorro.pid', 'w') { |file| file.write(Process.pid) }
else File.open('pids/rails.pid', 'w') { |file| file.write("Oops, it seems you entered wrong arguments. Only \"Spaghetti\" and \"Zorro\" are supported.") }
end

require 'rubygems'
require 'eventmachine'
require 'timeout'
require File.join(File.expand_path(File.dirname(__FILE__)),'/Resources/Stat_client.rb')
require File.join(File.expand_path(File.dirname(__FILE__)),'/Resources/Clerk.rb')


class Rails_log_analyzer
	module Log_analyzer
		@@obj = {}

		def notify_readable
			new_log_entry = @io.readline
			ip = new_log_entry.scan(/ip.\d+.\d+.\d+.\d+/)
			pid = new_log_entry.scan(/ruby\[(\d+)\]/)
			if pid.any?
        if ip.any?
				  ip = ip[0][3..-1]
        else
          ip = new_log_entry.scan(/domU.\d+.\d+.\d+.\d+.\d+.\w+/)
          ip = ip[0][5..-1]
        end
			  	pid = pid.flatten[0]
			  	task_status = new_log_entry.scan(/: \W*\w+/)[0][2..-1]
			  	key = ip + " : " + pid
			  	case task_status
			   		when "Started"
			    		if @@obj.keys.include?(key)
			  				puts "error"
			  			else	
#add the incoming request to hash, start the timer, enter into state machine
  						@@obj[key]={:object =>State_machine.new} 
  						@@obj[key][:timer] = EventMachine::Timer.new(120)do 
  		        	puts @@obj[key][:object].controller.to_s + " Request-Bounced"
  		         	Statsd.increment(State_machine.stat_type + @@obj[key][:object].controller.to_s + ".Bounced-Requests")
  		         	@@obj.delete(key)
  	        	end
  						@@obj[key][:object].started(key) 
  						end
  			
  					when "Processing"
  			  		if @@obj.keys.include?(key) 
  							@@obj[key][:object].processing(new_log_entry)
  						end
  					
  					when "Write"
  						if @@obj.keys.include?(key)
  							@@obj[key][:object].write(new_log_entry,key)
  						end
  					
  					when "Completed"
  			  		if @@obj.keys.include?(key)
   							@@obj[key][:timer].cancel
	  		  			@@obj[key][:object].completed(new_log_entry,key)
	  						@@obj.delete(key)
	  		  		end
	  	    end
	   	  end
			rescue EOFError
		end
	end

		def traverser
			EM.run do
				fp = [] #array to store file descriptors
				conn = {} #hash for connections
				i = 1
				while i < ARGV.length do
					fp[i] = open(ARGV[i],"r")
					conn[fp[i]] = EM.watch(fp[i],Log_analyzer)
					conn[fp[i]].notify_readable = true
					i = i + 1
				end
			end
		end

		def self.min_count
			min_val = (Time.now.to_i/60)
		end
end

class State_machine
  attr_accessor :cur_state, :start_time, :controller
	def self.stat_type
		if !ARGV[0].to_s.nil?
			ARGV[0].to_s + ".Controller-Info."
		else
			"Controller-Info."
		end
	end

  def started(key)
    @cur_state = "started"
    @start_time = Rails_log_analyzer.min_count
    puts "New incoming request for :" + key.to_s
    Statsd.increment(State_machine.stat_type + "Incoming-requests")
  end

  def processing(new_log_entry)
    @cur_state = "processing"
    ctrl = new_log_entry.scan(/ \w*[^ ]*\w+Controller#\w+ /)[0][1..-2].gsub("#","--")  
		puts "Processing the " + ctrl.to_s
		@controller = ctrl
		Statsd.increment(State_machine.stat_type + @controller.to_s + ".Hits")
	end

	def write(new_log_entry,key)
		@cur_state = "write"
		duration = new_log_entry.scan(/\(.*\)$/)[0][1..-5]
		puts @controller.to_s + " write time: " + duration.to_s + " ( " + key.to_s + ")"
		Statsd.gauges(State_machine.stat_type + @controller.to_s + ".Write-Time", duration)
	end

	def completed(new_log_entry,key)
		@cur_state = "completed"
		duration = new_log_entry.scan(/in [0-9]+\.?[0-9]*ms/)
		puts @controller.to_s + " Completed Time: " + duration.to_s + " ( " + key.to_s + " ) "	
		Statsd.gauges(State_machine.stat_type + @controller.to_s + ".Completion-Time", duration)
	end 
end

Rails_log_analyzer.new.traverser
