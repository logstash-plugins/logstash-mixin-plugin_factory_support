# encoding: utf-8

require 'rspec/its'

require "logstash-core"

require 'logstash/inputs/base'
require 'logstash/filters/base'
require 'logstash/codecs/base'
require 'logstash/outputs/base'

require 'logstash/codecs/plain' # to init base plugin with default codec

require "logstash/plugin_mixins/plugin_factory_support"

describe LogStash::PluginMixins::PluginFactorySupport do
  let(:plugin_factory_support) { described_class }

  context 'included into a class' do
    context 'that does not inherit from `LogStash::Plugin`' do
      let(:plugin_class) { Class.new }
      it 'fails with an ArgumentError' do
        expect do
          plugin_class.send(:include, plugin_factory_support)
        end.to raise_error(ArgumentError, /LogStash::Plugin/)
      end
    end

    [
      LogStash::Inputs::Base,
      LogStash::Filters::Base,
      LogStash::Codecs::Base,
      LogStash::Outputs::Base
    ].each do |base_class|
      context "that inherits from `#{base_class}`" do
        native_support_for_plugin_factory = base_class.method_defined?(:plugin_factory)

        let(:plugin_base_class) { base_class }

        subject(:plugin_class) do
          Class.new(plugin_base_class) do
            config_name 'test'
          end
        end

        context 'the result' do
          before(:each) do
            plugin_class.send(:include, plugin_factory_support)
          end

          it 'defines an `plugin_factory` method' do
            expect(plugin_class.method_defined?(:plugin_factory)).to be true
          end

          # depending on which version of Logstash is running, we either expect
          # to include or to _NOT_ include the legacy adapter.
          if native_support_for_plugin_factory
            context 'since base class provides plugin_factory method' do
              its(:ancestors) { is_expected.to_not include(plugin_factory_support::LegacyAdapter) }
            end
          else
            context 'since base class does not plugin_factory method' do
              its(:ancestors) { is_expected.to include(plugin_factory_support::LegacyAdapter) }
            end

            # TODO: Remove once Plugin Factory is included in one or
            #       more Logstash release branches. This speculative spec is meant
            #       to prove that this implementation will not override an existing
            #       implementation.
            context 'if base class were to include a plugin_factory method' do
              let(:plugin_base_class) do
                Class.new(super()) do
                  def plugin_factory
                  end
                end
              end
              before(:each) do
                expect(plugin_base_class.method_defined?(:plugin_factory)).to be true
              end
              its(:ancestors) { is_expected.to_not include(plugin_factory_support::LegacyAdapter) }
            end
          end

          context 'when intialized' do
            let(:plugin_options) { Hash.new }
            subject(:instance) { plugin_class.new(plugin_options) }

            describe '#plugin_factory' do
              it 'returns a plugin factory' do
                pf = instance.plugin_factory

                expect(pf).to respond_to(:input)
                expect(pf).to respond_to(:output)
                expect(pf).to respond_to(:codec)
                expect(pf).to respond_to(:filter)
              end

              context 'PluginFactory' do
                let(:execution_context) do
                  # If we are running on a Logstash that has a Plugin Contextualizer,
                  # it needs a real-deal ExecutionContext due to java type-casting.
                  if defined?(::LogStash::Plugins::Contextualizer)
                    ::LogStash::ExecutionContext.new(nil, nil)
                  else
                    double('LogStash::ExecutionContext').as_null_object
                  end
                end

                before(:each) do
                  expect(instance).to receive(:execution_context).and_return(execution_context)
                end

                describe '#codec(plain).new("format" => "foo/bar")' do
                  it 'creates a contextualized instance' do
                    plain_codec_factory = instance.plugin_factory.codec('plain')
                    product = plain_codec_factory.new("format" => "foo/bar")

                    aggregate_failures('standard params parsing') do
                      expect(product).to be_a_kind_of(::LogStash::Codecs::Plain)
                      expect(product.format).to eq("foo/bar")
                    end

                    aggregate_failures('contextualizing') do
                      expect(product.execution_context).to be(execution_context) # propagate!
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
