# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-google-cloud-storage"
  gem.version       = "1.0.2"
  gem.authors       = ["Hsiu-Fan Wang"]
  gem.email         = ["hfwang@porkbuns.net"]
  gem.summary       = %q{Fluentd plugin to write data to Google Cloud Storage}
  gem.description   = %q{Google Cloud Storage fluentd output}
  gem.homepage      = "https://github.com/sonicmoov/fluent-plugin-google-cloud-storage"
  gem.license       = "APLv2"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rake"
  gem.add_development_dependency "test-unit", "~> 3.0.2"
  
  
  gem.add_runtime_dependency "fluentd", "~> 0.12.0"
  gem.add_runtime_dependency "fluent-mixin-plaintextformatter", '>= 0.2.1'
  gem.add_runtime_dependency "fluent-mixin-config-placeholders", ">= 0.3.0"
  gem.add_runtime_dependency "google-api-client", "~> 0.9.3"
  gem.add_runtime_dependency "mime-types", '>= 3.0'
end


