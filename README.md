# Plugin Factory Support Mixin

[![Build Status](https://travis-ci.com/logstash-plugins/logstash-mixin-plugin_factory_support.svg?branch=main)](https://travis-ci.com/logstash-plugins/logstash-mixin-plugin_factory_support)

This gem provides an API-compatible implementation of a Plugin Factory,
which hooks into Logstash internals
.

## Usage (simple)

1. Add version `~>1.0` of this gem as a runtime dependency of your Logstash plugin's `gemspec`:

    ~~~ ruby
    Gem::Specification.new do |s|
      # ...

      s.add_runtime_dependency 'logstash-mixin-plugin_factory_support', '~>1.0'
    end
    ~~~

2. In your plugin code, require this library and include it into your plugin class
   that already inherits `LogStash::Plugin`:

    ~~~ ruby
    require 'logstash/plugin_mixins/plugin_factory_support'

    class LogStash::Inputs::Foo < Logstash::Inputs::Base
      include LogStash::PluginMixins::PluginFactorySupport

      # ...
    end
    ~~~

3. When instantiating other plugins from inside your plugin, _do not_ send `new`
   to the plugin class directly. Instead use the `plugin_factory`
   method to obtain a PluginFactory, and then use one of its `#input`, `#output`,
   `#codec`, or `#filter` methods with your plugin's name to obtain a proxy for
   the plugin class, and then send the proxy `#new` with your options as normal.
   This will ensure that the inner plugin instance is properly bound to the pipeline
   and execution context from the outer plugin.

    ~~~ ruby
      def register
        @internal_grok = plugin_factory.filter('grok').new("match" => {"message" => "^PATTERN"})
      end
    ~~~

    Expressed as a diff:

    ~~~ diff
       def register
    -    @internal_grok = ::LogStash::Filter::Grok.new("match" => {"message" => "^PATTERN"})
    +    @internal_grok = plugin_factory.filter('grok').new("match" => {"message" => "^PATTERN"})
       end

    ~~~

## Development

This gem:
 - *MUST* remain API-stable at 1.x
 - *MUST NOT* introduce additional runtime dependencies
