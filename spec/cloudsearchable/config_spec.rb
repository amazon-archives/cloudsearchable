require 'spec_helper'

describe Cloudsearchable::Config do
  it 'can be set in a block' do
    Cloudsearchable.configure do |config|
      config.domain_prefix = 'dev-llarue-'
    end

    Cloudsearchable.configure.domain_prefix.should eq 'dev-llarue-'
  end

  it 'aliases configure to config' do
    Cloudsearchable.config.domain_prefix.should eq Cloudsearchable.configure.domain_prefix
  end
end
