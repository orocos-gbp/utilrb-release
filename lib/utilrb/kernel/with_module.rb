require 'utilrb/common'
module Kernel
    module WithModuleConstResolutionExtension
        def const_missing(const_name)
            if with_module_setup = Thread.current[:__with_module__]
                if consts = with_module_setup.last
                    consts.each do |mod|
                        if mod.const_defined?(const_name)
                            return mod.const_get(const_name)
                        end
                    end
                end
            end
            super
        end
    end

    def with_module(*consts, &block)
        Thread.current[:__with_module__] ||= Array.new
        Thread.current[:__with_module__].push consts
        Kernel.send(:extend, WithModuleConstResolutionExtension)
        Object.extend WithModuleConstResolutionExtension

        eval_string =
            if !block_given? && consts.last.respond_to?(:to_str)
                consts.pop
            end
        if eval_string
            instance_eval(eval_string)
        else
            instance_eval(&block)
        end

    ensure
        Thread.current[:__with_module__].pop
    end
end

