require 'utilrb/object/attribute'
module CachedValuesSupport
    attribute(:cached_variables) { Set.new }
    def initialize_copy(other)
        super

        cached_variables.each do |varname|
            instance_variable_set(varname, nil)
        end
    end
end

class Module
    # Creates <tt>enum_#{name}</tt> method which returs an Enumerator object
    # for the <tt>each_#{enum_name}</tt> method. This enumerator is created
    # once.
    #
    # If +with_arg+ is true, it is supposed that the 'each_' method requires
    # one argument, which is given in argument of the 'enum' method. In that
    # case, an enumerator is created for each argument
    def cached_enum(enum_name, name, with_arg)
        include CachedValuesSupport
	if with_arg
	    class_eval <<-EOD, __FILE__, __LINE__+1
		def enum_#{name}(arg)
		    @enum_#{name} ||= Hash.new
                    cached_variables << :@enum_#{name}
		    @enum_#{name}[arg] ||= enum_for(:each_#{enum_name}, arg)
		end
		EOD
	else
	    class_eval <<-EOD, __FILE__, __LINE__+1
		def enum_#{name}
                    cached_variables << :@enum_#{name}
		    @enum_#{name} ||= enum_for(:each_#{enum_name})
		end
		EOD
	end
    end
end

