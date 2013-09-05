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
    subject.foo.should eq 5
  end

  it 'defaults' do
    subject.warnings.should_not be_nil
    subject.warnings.should eq subject.settings[:warnings]
  end

  it 'resets option' do
    subject.timezone = "EST"
    subject.timezone.should eq "EST"
    subject.reset_timezone
    subject.timezone.should eq "PST"
  end

  it 'resets all options' do
    subject.foo = 5
    subject.reset
    subject.foo.should eq nil
  end

end
