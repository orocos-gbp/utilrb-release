require 'utilrb/test'
require 'utilrb/set'

class TC_Set < Minitest::Test
    def test_to_s
	obj = Set.new
	obj << 1
	obj << 2
	assert(obj.to_s =~ /^\{(.*)\}$/)
	values = $1.split(", ")
	assert_equal(["1", "2"].to_set, values.to_set)

	obj << obj
	assert(obj.to_s =~ /^\{(.*)\}$/)
	values = $1.split(", ")
	assert_equal(["1", "2", "..."].to_set, values.to_set)
    end
end

