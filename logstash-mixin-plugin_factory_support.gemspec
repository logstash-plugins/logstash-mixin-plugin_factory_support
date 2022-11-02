Gem::Specification.new do |s|
  s.name          = 'logstash-mixin-plugin_factory_support'
  s.version       = '1.0.0'
  s.licenses      = %w(Apache-2.0)
  s.summary       = "API-stable Plugin Factory support adapter for Logstash plugins"
  s.description   = "This gem is meant to be a dependency of any Logstash plugin that wishes to use a Plugin Factory to instantiate inner plugins that are fully-contextualized in the pipeline that the outer plugin is running in"
  s.authors       = %w(Elastic)
  s.email         = 'info@elastic.co'
  s.homepage      = 'https://github.com/logstash-plugins/logstash-mixin-plugin_factory_support'
  s.require_paths = %w(lib)

  s.files = %w(lib spec vendor).flat_map{|dir| Dir.glob("#{dir}/**/*")}+Dir.glob(["*.md","LICENSE"])

  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  s.platform = 'java'

  s.add_runtime_dependency 'logstash-core', '>= 7.13.0'

  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'rspec', '~> 3.9'
  s.add_development_dependency 'rspec-its', '~>1.3'
  s.add_development_dependency 'logstash-codec-plain', '>= 3.1.0'
end
