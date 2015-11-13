require 'spec_helper'

describe Cloudsearchable::Config do
  it 'can be set in a block' do
    Cloudsearchable.configure do |config|
      config.domain_prefix = 'dev-llarue-'
    end

    expect(Cloudsearchable.configure.domain_prefix).to eq 'dev-llarue-'
  end

  it 'aliases configure to config' do
    expect(Cloudsearchable.config.domain_prefix).to eq Cloudsearchable.configure.domain_prefix
  end
end
