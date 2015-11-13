require 'spec_helper'
require 'ostruct'

describe Cloudsearchable::Field do
  before :all do
    ENV['AWS_REGION'] = 'us-east-1'
  end

  it 'has a name' do
    field = described_class.new 'fnord', :literal
    expect(field.name).to eq(:fnord)
  end

  it 'can find its value' do
    test_value = nil
    field = described_class.new('foo', :literal, :source => Proc.new { test_value })
    test_value = 123
    expect(field.value_for(Object.new)).to eq(test_value)

    record = OpenStruct.new :a => test_value
    field2 = described_class.new('bar', :literal, :source => :a)
    expect(field.value_for(record)).to eq(test_value)
  end

  it 'generates a field definition' do
    domain_name = 'narnia'
    field = described_class.new('fnord', :literal, :search_enabled => true)
    expect(CloudSearch.client).to receive(:define_index_field) do |call|
      expect(call[:domain_name]).to eq(domain_name)
      expect(call[:index_field][:literal_options][:search_enabled]).to be true
    end
    field.define_in_domain domain_name
  end
end
