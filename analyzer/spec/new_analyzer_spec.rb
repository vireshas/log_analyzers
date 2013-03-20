require File.join(File.expand_path(File.dirname(__FILE__)),'../new_analyzer.rb')

describe "Rails_log_analyzer" do
	describe "#process" do
		it "test" do
			r = Rails_log_analyzer.new
			r.notify_readable("ip.123.123.123.12 ruby[456] : Started ")
			r.notify_readable("ip.123.123.123.12 ruby[456] : Completed ")
		end
	end
end
  
