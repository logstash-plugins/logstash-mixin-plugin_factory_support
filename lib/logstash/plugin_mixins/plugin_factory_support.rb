# encoding: utf-8

require 'java'
require 'thread'

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
        INIT_MUTEX = Mutex.new
        private_constant :INIT_MUTEX

        ##
        # @return [PluginFactory]
        def plugin_factory
          @_plugin_factory || INIT_MUTEX.synchronize do
            @_plugin_factory ||= PluginFactory.new(self)
          end
        end

        ##
        # A PluginFactory provides methods for retrieving plugin
        # classes that can be initialized with a pre-determined ExecutionContext.
        class PluginFactory

          def initialize(outer_plugin)
            @outer_plugin = outer_plugin

            sequence_id = java.util.concurrent.atomic.AtomicLong.new(0)
            @sequence_generator = proc { sequence_id.increment_and_get }
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
            @outer_plugin.execution_context
          end

          def outer_plugin_id
            @outer_plugin.id
          end

          def next_sequence_id
            @sequence_generator.call
          end
        end

        ##
        # A PluginClassProxy responds to `new` with a string-keyed params hash,
        # and is a proxy for the ruby plugin class associated with its type and name.
        class PluginClassProxy
          def initialize(plugin_factory, plugin_type, plugin_name)
            @plugin_type = plugin_type
            @plugin_name = plugin_name
            @plugin_factory = plugin_factory
          end

          ##
          # Creates an instance of the plugin using the provided parameters
          # that has access to the factory's execution context.
          #
          # If an `id` is not explicitly provided, a sensible one will be generated
          # indicating its relationship to the plugin in which it was instantiated.
          #
          # @param params [Hash{String=>Object}]
          # @return [LogStash::Plugin]
          def new(params={})
            params_with_id = params.include?('id') ? params : params.merge('id' => generate_inner_id)

            initialize_contextualized_plugin(params_with_id)
          end

          private

          if defined?(::LogStash::Plugins::Contextualizer)

            # In Logstash 7.10+, we have a contextualizer that pre-injects context
            def initialize_contextualized_plugin(params)
              ::LogStash::Plugins::Contextualizer.initialize_plugin(@plugin_factory.execution_context, plugin_class, params)
            end

          else

            # In older Logstashes, we cannot inject context before initialization happens.
            # so we do our best and inject immediately after initialize is called.
            def initialize_contextualized_plugin(params)
              plugin_class.new(params).tap do |plugin_instance|
                plugin_instance.execution_context = @plugin_factory.execution_context
              end
            end

          end

          def plugin_class
            ::LogStash::Plugin.lookup(@plugin_type, @plugin_name)
          end

          def generate_inner_id
            "#{@plugin_factory.outer_plugin_id}/inner-#{@plugin_type}-#{@plugin_name}@#{@plugin_factory.next_sequence_id}"
          end
        end
      end
    end
  end
end
