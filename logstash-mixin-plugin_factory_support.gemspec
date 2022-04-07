Gem::Specification.new do |s|
  s.name          = 'logstash-mixin-plugin_factory_support'
  s.version       = '1.0.0'
  s.licenses      = %w(Apache-2.0)
  s.summary       = "Support for the Plugin Factory introduced in Logstash 8.3, for plugins wishing to use this API on older Logstashes"
  s.description   = "This gem is meant to be a dependency of any Logstash plugin that wishes to use the Plugin Factory introduced in Logstash 8.3 while maintaining backward-compatibility with earlier Logstash releases. When used on older Logstash versions, this adapter provides an implementation of `Plugin#plugin_factory`"
  s.authors       = %w(Elastic)
  s.email         = 'info@elastic.co'
  s.homepage      = 'https://github.com/logstash-plugins/logstash-mixin-plugin_factory_support'
  s.require_paths = %w(lib)

  s.files = %w(lib spec vendor).flat_map{|dir| Dir.glob("#{dir}/**/*")}+Dir.glob(["*.md","LICENSE"])

  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  s.platform = RUBY_PLATFORM

  s.add_runtime_dependency 'logstash-core', '>= 6.0.0'

  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'rspec', '~> 3.9'
  s.add_development_dependency 'rspec-its', '~>1.3'
  s.add_development_dependency 'logstash-codec-plain', '>= 3.1.0'
end
