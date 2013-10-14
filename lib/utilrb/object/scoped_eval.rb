require 'utilrb/common'
require 'utilrb/kernel/with_module'
class Object
    if Utilrb::RUBY_IS_191
        def scoped_eval(type = :instance_eval, &b)
            modules = b.binding.eval "Module.nesting"
            with_module(*modules) do
                send(type, &b)
            end
        end
    else
        def scoped_eval(type = :instance_eval, &b)
            send(type, &b)
        end
    end
end

