require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'cloudsearchable'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end