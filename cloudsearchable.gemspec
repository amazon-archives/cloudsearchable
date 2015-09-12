# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cloudsearchable/version'

Gem::Specification.new do |spec|
  spec.name          = "cloudsearchable"
  spec.version       = Cloudsearchable::VERSION
  spec.authors       = ["Lane LaRue"]
  spec.email         = ["llarue@amazon.com"]
  spec.description   = %q{ActiveRecord-like query interface for AWS Cloud Search}
  spec.summary       = %q{ActiveRecord-like query interface for AWS Cloud Search}
  spec.homepage      = ""
  spec.license       = "MIT"

  # generated with `git ls-files`.split($/)
  spec.files = [
      ".rspec",
      "Gemfile",
      "LICENSE.txt",
      "README.md",
      "Rakefile",
      "cloudsearchable.gemspec",
      "lib/cloudsearchable.rb",
      "lib/cloudsearchable/cloud_search.rb",
      "lib/cloudsearchable/config.rb",
      "lib/cloudsearchable/config/options.rb",
      "lib/cloudsearchable/domain.rb",
      "lib/cloudsearchable/field.rb",
      "lib/cloudsearchable/query_chain.rb",
      "lib/cloudsearchable/version.rb",
      "spec/cloudsearchable/cloud_search_spec.rb",
      "spec/cloudsearchable/cloudsearchable_spec.rb",
      "spec/cloudsearchable/config/option_spec.rb",
      "spec/cloudsearchable/config_spec.rb",
      "spec/cloudsearchable/domain_spec.rb",
      "spec/cloudsearchable/field_spec.rb",
      "spec/cloudsearchable/query_chain_spec.rb",
      "spec/spec_helper.rb",
      "spec/test_classes/cloud_searchable_test_class.rb"
  ]

  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "yard"
  spec.add_dependency 'aws-sdk', "~> 2"

  # testing dependencies
  spec.add_development_dependency "rspec", '~> 2'
  spec.add_development_dependency "activemodel"
end
