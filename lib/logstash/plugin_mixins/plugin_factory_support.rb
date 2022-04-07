# encoding: utf-8

require 'logstash/namespace'
require 'logstash/plugin'

module LogStash
  module PluginMixins
    ##
    # This `PluginFactorySupport` can be included in any `LogStash::Plugin`,
    # and will ensure that the plugin provides an `plugin_factory` method that
    # returns a factory for instantiating plugins with as much context as possible.
    #
    # When included into a Logstash plugin that already has a plugin factory (e.g.,
    # when run on a Logstash release that provides a plugin factory),
    # this adapter will _NOT_ override the existing implementation.
    module PluginFactorySupport

      ##
      # @api internal (use: `LogStash::Plugin::include`)
      # @param base [Class]: a class that inherits `LogStash::Plugin`, typically one
      #                      descending from one of the four plugin base classes
      #                      (e.g., `LogStash::Inputs::Base`)
      # @return [void]
      def self.included(base)
        fail(ArgumentError, "`#{base}` must inherit LogStash::Plugin") unless base < LogStash::Plugin

        # If our base does not include an `plugin_factory`,
        # include the legacy adapter to ensure it gets defined.      
        base.send(:include, LegacyAdapter) unless base.method_defined?(:plugin_factory)
      end

      ##
      # This `PluginFactorySupport` cannot be extended into an existing object.
      # @api private
      #
      # @param base [Object]
      # @raise [ArgumentError]
      def self.extended(base)
        fail(ArgumentError, "`#{self}` cannot be extended into an existing object.")
      end

      ##
      # Implements `plugin_factory` method, which returns a `PluginFactory`
      #
      # @api internal
      module LegacyAdapter

        ##
        # @return [PluginFactory]
        def plugin_factory
          PluginFactory.new(self)
        end

        ##
        # A PluginFactory provides methods for retrieving plugin
        # classes that can be initialized with a pre-determined ExecutionContext.
        class PluginFactory
          def initialize(execution_context_provider)
            @execution_context_provider = execution_context_provider
          end

          %i(
            input
            output
            codec
            filter
          ).each do |plugin_type|
            define_method(plugin_type) do |plugin_name|
              PluginClassProxy.new(self, plugin_type, plugin_name)
            end
          end

          def execution_context
            @execution_context_provider.execution_context
          end
        end

        class PluginClassProxy
          def initialize(plugin_factory, plugin_type, plugin_name)
            @plugin_type = plugin_type
            @plugin_name = plugin_name
            @plugin_factory = plugin_factory
          end

          if defined?(::LogStash::Plugins::Contextualizer)

            # In Logstash 7.10+, we have a contextualizer that pre-injects context
            def new(params={})
              ::LogStash::Plugins::Contextualizer.initialize_plugin(@plugin_factory.execution_context, plugin_class, params)
            end

          else

            # In older Logstashes, we cannot inject context before initialization happens.
            # so we do our best and inject immediately after initialize is called.
            def new(params={})

              plugin_class.new(params).tap do |plugin_instance|
                plugin_instance.execution_context = @plugin_factory.execution_context
              end
            end

          end

          private

          def plugin_class
            ::LogStash::Plugin.lookup(@plugin_type, @plugin_name)
          end
        end
      end
    end
  end
end
