name_arr = `df | awk '{print $1}' | grep -v '^Filesystem' | grep -e "/dev/"`.split("\n")

val_arr = []

name_arr.each do |c| val_arr << open("| sudo smartctl -H -d auto #{c} | tail -2 | awk 'FNR == 1 {if ($6 == \"FAILED\") {print \"0\";} else{print \"1\";}}'").read end

if ARGV[0] == "names"
	puts name_arr
elsif ARGV[0] == "vals"
	puts val_arr
end
