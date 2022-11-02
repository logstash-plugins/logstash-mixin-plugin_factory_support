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
            subject(:instance) do
              plugin_class.new(plugin_options).tap do |i|
                i.execution_context = outer_execution_context
              end
            end

            let(:outer_execution_context) do
              # If we are running on a Logstash that has a Plugin Contextualizer,
              # it needs a real-deal ExecutionContext due to java type-casting.
              if defined?(::LogStash::Plugins::Contextualizer)
                ::LogStash::ExecutionContext.new(nil, nil)
              else
                double('LogStash::ExecutionContext').as_null_object
              end
            end

            describe '#plugin_factory' do
              it 'returns a plugin factory' do
                pf = instance.plugin_factory

                aggregate_failures do
                  expect(pf).to respond_to(:input)
                  expect(pf).to respond_to(:output)
                  expect(pf).to respond_to(:codec)
                  expect(pf).to respond_to(:filter)
                end
              end

              context 'PluginFactory' do

                describe '#codec("plain").new' do
                  let(:plain_codec_proxy) { instance.plugin_factory.codec('plain') }
                  before(:each) do
                    allow(plain_codec_proxy).to receive(:logger).and_return(double('Logger').as_null_object)
                  end

                  let(:inner_params) { Hash.new }

                  subject(:inner_plugin) { plain_codec_proxy.new(inner_params) }

                  shared_examples 'contextualized instance' do
                    alias_matcher :same_instance_as, :equal
                    it 'has access to the execution_context' do
                      expect(inner_plugin).to have_attributes(execution_context: same_instance_as(outer_execution_context))
                    end
                    it 'logs a breadcrumb linking the inner plugin to its outer wrapper' do
                      inner_plugin # eager instantiate

                      expect(plain_codec_proxy.logger).to have_received(:debug).with(a_string_including('initializing inner plain codec'),
                                                                                     a_hash_including(inner_plugin_id: inner_plugin.id, outer_plugin_id: instance.id))
                    end
                  end

                  shared_examples 'params propagation' do
                    it 'propagates the explicitly-passed parameters' do
                      expect(inner_plugin).to have_attributes(original_params: a_hash_including(inner_params))
                    end
                  end

                  shared_examples 'sensible generated id' do
                    it 'has a sensible generated id' do
                      expect(inner_plugin).to have_attributes(id: a_string_starting_with("#{instance.id}/inner-codec-plain@"))
                    end
                    context 'when multiple plugin instances are generated from the same factory' do
                      subject(:inner_plugins) do
                        instance # eager init outer instance in main thread
                        10.times.map do
                          Thread.new(inner_params.dup) do |isolated_inner_params|
                            100.times.map do
                              instance.plugin_factory.codec('plain').new(isolated_inner_params)
                            end
                          end
                        end.map(&:value).flatten
                      end
                      it 'generates distinct ids' do
                        expect(inner_plugins.map(&:id)).to_not contain_duplicates
                      end

                      matcher :contain_duplicates do
                        match do |actual|
                          actual.uniq != actual
                        end
                        failure_message_when_negated do |actual|
                          actual_formatted = RSpec::Support::ObjectFormatter.format(actual)
                          duplicate_counts = actual.each_with_object(Hash.new{0}) { |id,m| m[id] += 1 }
                                                   .reject {|value, count| count <= 1 }
                          "expected #{actual_formatted} to not contain duplicates but found #{duplicate_counts}"
                        end
                      end
                    end
                  end

                  shared_examples 'explicit id propagation' do
                    let(:explicit_id) { inner_params.fetch("id") }
                    it 'propagates the explicitly-given id' do
                      expect(inner_plugin).to have_attributes(id: explicit_id)
                    end
                  end

                  context 'with params `"format" => "foo/bar"`' do
                    let(:inner_params) { super().merge("format" => "foo/bar") }

                    include_examples "contextualized instance"
                    include_examples "params propagation"
                    include_examples "sensible generated id"

                    context 'and explicit id' do
                      let(:inner_params) { super().merge("id" => "explicitly-given-id") }

                      include_examples "contextualized instance"
                      include_examples "params propagation"
                      include_examples "explicit id propagation"
                    end
                  end

                  context 'with explicit id' do
                    let(:inner_params) { super().merge("id" => "explicitly-given-id") }

                    include_examples "contextualized instance"
                    include_examples "params propagation"
                    include_examples "explicit id propagation"
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
