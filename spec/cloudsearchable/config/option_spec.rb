require 'spec_helper'
#require 'cloudsearchable/config/options'

describe Cloudsearchable::Config::Options do

  module ConfigTest
    extend self
    include Cloudsearchable::Config::Options

    option :foo
    option :timezone, :default => "PST"
    option :warnings, :default => false
  end

  subject { ConfigTest }

  it 'sets and gets' do
    subject.foo = 5
    expect(subject.foo).to eq 5
  end

  it 'defaults' do
    expect(subject.warnings).to_not be_nil
    expect(subject.warnings).to eq subject.settings[:warnings]
  end

  it 'resets option' do
    subject.timezone = "EST"
    expect(subject.timezone).to eq "EST"
    subject.reset_timezone
    expect(subject.timezone).to eq "PST"
  end

  it 'resets all options' do
    subject.foo = 5
    subject.reset
    expect(subject.foo).to be_nil
  end

end
