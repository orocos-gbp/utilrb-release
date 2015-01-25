require 'utilrb/common'
require 'utilrb/object/singleton_class'
require 'utilrb/kernel/with_module'

module Kernel
    def self.backtrace_remove_first_occurence_of(e, rx)
        # Remove the first occurence of eval_dsl_file_content in the backtrace
        backtrace = e.backtrace.dup
        found = false
        backtrace.delete_if do |line|
            break if found
            line =~ rx
            found = true
        end
        raise e, e.message, e.backtrace
    end

    def load_dsl_filter_backtrace(file, full_backtrace = false, *exceptions)
        # Compute the position of the dsl-loading method that called us, so that
        # we don't touch anything below that while we are filtering the
        # backtrace
        if !full_backtrace
            callers = caller
            our_frame_pos = caller.size
            callers.each do |line|
                if line != /load_dsl_file\.rb/
                    our_frame_pos -= 1
                else
                    break
                end
            end
        end

        yield

    rescue Exception => e
        raise e if full_backtrace
        if exceptions.any? { |e_class| e.kind_of?(e_class) }
            raise e
        end

        backtrace = e.backtrace.dup
        message   = e.message.dup

        # Filter out the message ... it can contain backtrace information as
        # well (!)
        message = message.split("\n").map do |line|
            if line =~ /^.*:\d+(:.*)$/
                backtrace.unshift line
                nil
            else
                line
            end
        end.compact.join("\n")


        if message.empty?
            message = backtrace.shift
            if message =~ /^(\s*[^\s]+:\d+:)\s*(.*)/
                location = $1
                message  = $2
                backtrace.unshift location
            else
                backtrace.unshift message
            end
        end

        filtered_backtrace = backtrace[0, backtrace.size - our_frame_pos].
            map do |line|
                line = line.gsub(/:in `.*dsl.*'/, '')
                if line =~ /load_dsl_file.*(method_missing|send)/
                    next
                end

                if line =~ /(load_dsl_file\.rb|with_module\.rb):\d+/
                    next
                else
                    line
                end
            end.compact


        backtrace = (filtered_backtrace[0, 1] + filtered_backtrace + backtrace[(backtrace.size - our_frame_pos)..-1])
        raise e, message, backtrace
    end

    def eval_dsl_block(block, proxied_object, context, full_backtrace, *exceptions)
        load_dsl_filter_backtrace(nil, full_backtrace, *exceptions) do
            proxied_object.with_module(*context, &block)
            true
        end
    end

    def eval_dsl(text, proxied_object, context, full_backtrace, *exceptions)
        eval_dsl_file_content(nil, text, proxied_object, context, full_backtrace, *exceptions)
    end

    def eval_dsl_file_content(file, file_content, proxied_object, context, full_backtrace, *exceptions)
        code = with_module(*context) do
            code =  <<-EOD
            Proc.new { #{file_content} }
            EOD
            if file
                eval code, binding, file, 1
            else
                eval code, binding
            end
        end

        dsl_exec_common(file, proxied_object, context, full_backtrace, *exceptions, &code)
    end

    # Load the given file by eval-ing it in the provided binding. The
    # originality of this method is to translate errors that are detected in the
    # eval'ed code into errors that refer to the provided file
    #
    # The caller of this method should call it at the end of its definition
    # file, or the translation method may not be robust at all
    def eval_dsl_file(file, proxied_object, context, full_backtrace, *exceptions, &block)
        if !File.readable?(file)
            raise ArgumentError, "#{file} does not exist"
        end

        loaded_file = file.gsub(/^#{Regexp.quote(Dir.pwd)}\//, '')
        file_content = File.read(file)
        eval_dsl_file_content(loaded_file, file_content, proxied_object, context, full_backtrace, *exceptions, &block)
    end

    # Same than eval_dsl_file, but will not load the same file twice
    def load_dsl_file(file, *args, &block)
        file = File.expand_path(file)
        if $LOADED_FEATURES.include?(file)
            return false
        end

        $LOADED_FEATURES << file
        begin
            eval_dsl_file(file, *args, &block)
        rescue Exception
            $LOADED_FEATURES.delete(file)
            raise
        end
        true
    end

    def dsl_exec(proxied_object, context, full_backtrace, *exceptions, &code)
        dsl_exec_common(nil, proxied_object, context, full_backtrace, *exceptions, &code)
    end

    def dsl_exec_common(file, proxied_object, context, full_backtrace, *exceptions, &code)
        load_dsl_filter_backtrace(file, full_backtrace, *exceptions) do
            sandbox = with_module(*context) do
                Class.new(BasicObject) do
                    def self.name; "" end
                    attr_accessor :main_object
                    def initialize(obj); @main_object = obj end
                    def method_missing(*m, &block)
                        main_object.__send__(*m, &block)
                    end
                end
            end

            old_constants, new_constants = Kernel.constants, nil

            sandbox = sandbox.new(proxied_object)
            sandbox.with_module(*context) do
                old_constants =
                    if respond_to?(:constants)
                        constants
                    else  self.class.constants
                    end

                instance_eval(&code)

                new_constants =
                    if respond_to?(:constants)
                        constants
                    else  self.class.constants
                    end
            end

            # Check if the user defined new constants by using class K and/or
            # mod Mod
            if !new_constants
                new_constants = Kernel.constants
            end

            new_constants -= old_constants
            new_constants.delete_if { |n| n.to_s == 'WithModuleConstResolutionExtension' }
            if !new_constants.empty?
                msg = "#{new_constants.first} does not exist. You cannot define new constants in this context"
                raise NameError.new(msg, new_constants.first)
            end
            true
        end
    end
end

