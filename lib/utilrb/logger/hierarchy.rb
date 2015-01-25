require 'facets/module/spacename'
require 'facets/kernel/constant'
require 'utilrb/object/attribute'
require 'utilrb/object/singleton_class'
require 'utilrb/logger/forward'

class Logger
    module HierarchyElement
        attribute :log_children do
            Array.new
        end

        # Makes it so that this level of the module hierarchy has its own
        # logger. If +new_progname+ and/or +new_level+ are nil, the associated
        # value are taken from the parent's logger.
        def make_own_logger(new_progname = nil, new_level = nil)
            new_logger = @logger || self.logger.dup
            if new_progname
                new_logger.progname = new_progname
            end
            if new_level
                new_logger.level = new_level
            end
            self.logger = new_logger
        end

        # Allows to change the logger object at this level of the hierarchy
        #
        # This is usually not used directly: a new logger can be created with
        # Hierarchy#make_own_logger and removed with Hierarchy#reset_own_logger
        def logger=(new_logger)
            @logger = new_logger
            log_children.each do |child|
                child.reset_default_logger
            end
        end

        # Removes a logger defined at this level of the module hierarchy. The
        # logging methods will now access the parent's module logger.
        def reset_own_logger
            @logger = nil
            log_children.each do |child|
                child.reset_default_logger
            end
        end

        def reset_default_logger
            @__utilrb_hierarchy__default_logger = nil
            log_children.each do |child|
                child.reset_default_logger
            end
        end

        def logger
            if defined?(@logger) && @logger
                return @logger 
            elsif defined?(@__utilrb_hierarchy__default_logger) && @__utilrb_hierarchy__default_logger
                return @__utilrb_hierarchy__default_logger
            end
        end
    end

    # Define a hierarchy of loggers mapped to the module hierarchy.
    #
    # It defines the #logger accessor which either returns the logger
    # attribute of the module, if one is defined, or its parent logger
    # attribute.
    #
    # This module is usually used in conjunction with the Logger::Root method:
    # 
    #   module First
    #     extend Logger.Root("First", :INFO)
    #
    #     module Second
    #       extend Hierarchy
    #     end
    #   end
    #
    # Second.logger will return First.logger. If we do Second.make_own_logger,
    # then a different object will be returned.
    #
    # "extend Hierarchy" will also add the Forward support if the parent module
    # has it.
    module Hierarchy
        include HierarchyElement

        # Exception raised when a module/class in the logger hierarchy cannot
        # find a parent logger
        class NoParentLogger < RuntimeError; end

        # Returns true if the local module has its own logger, and false if it
        # returns the logger of the parent
        def has_own_logger?
            defined?(@logger) && @logger
        end

        def self.included(obj) # :nodoc:
            if obj.singleton_class.ancestors.include?(::Logger::Forward)
                obj.send(:include, ::Logger::Forward)
            end
        end

        def self.extended(obj) # :nodoc:
            obj.logger # initialize the default logger. Also does some checking
            if obj.kind_of?(Module) && !obj.spacename.empty?
                parent_module = constant(obj.spacename)
                if (parent_module.singleton_class.ancestors.include?(::Logger::Forward))
                    obj.send(:extend, ::Logger::Forward)
                end
            end
        end

        # Returns the logger object that should be used to log at this level of
        # the module hierarchy
        def logger
            if logger = super
                return logger
            end

            @__utilrb_hierarchy__default_logger =
                if kind_of?(Module)
                    m = self
                    while m
                        if m.name && !m.spacename.empty?
                            parent_module =
                                begin
                                    constant(m.spacename)
                                rescue NameError
                                end
                            if parent_module.respond_to?(:logger)
                                break
                            end
                        end
                        if m.respond_to?(:superclass)
                            m = m.superclass
                        else
                            m = nil; break
                        end
                    end

                    if !m
                        raise NoParentLogger, "cannot find a logger for #{self}"
                    end
                    if parent_module.respond_to? :log_children
                        parent_module.log_children << self
                    end
                    parent_module.logger
                else
                    self.class.logger
                end
        end
    end
end


