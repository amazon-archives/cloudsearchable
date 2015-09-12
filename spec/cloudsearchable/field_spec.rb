require 'spec_helper'
require 'ostruct'

describe Cloudsearchable::Field do
  before :all do
    ENV['AWS_REGION'] = 'us-east-1'
  end

  it 'has a name' do
    field = described_class.new 'fnord', :literal
    field.name.should eq(:fnord)
  end

  it 'can find its value' do
    test_value = nil
    field = described_class.new('foo', :literal, :source => Proc.new { test_value })
    test_value = 123
    field.value_for(Object.new).should eq(test_value)

    record = OpenStruct.new :a => test_value
    field2 = described_class.new('bar', :literal, :source => :a)
    field.value_for(record).should eq(test_value)
  end

  it 'generates a field definition' do
    domain_name = 'narnia'
    field = described_class.new('fnord', :literal, :search_enabled => true)
    CloudSearch.client.should_receive(:define_index_field) do |call|
      call[:domain_name].should eq(domain_name)
      call[:index_field][:literal_options][:search_enabled].should be_true
    end
    field.define_in_domain domain_name
  end
end
