require 'rubygems'
require 'bundler/setup'
require 'rspec/collection_matchers'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'cloudsearchable'

RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.warn_about_potential_false_positives = false
  end
end