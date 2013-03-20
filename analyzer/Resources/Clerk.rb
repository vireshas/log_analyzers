$hst_name = `hostname`

class Clerk
	class << self

		def name_stamp(some_arr,pad,chop_flag = 0)
      some_arr = [some_arr].flatten
			some_arr.each do |label|
				label.insert 0, $hst_name.chop + "." + pad + "."

				if chop_flag!=0
					label.chop!
				end
			end
				
			return some_arr
		end

	end
end
