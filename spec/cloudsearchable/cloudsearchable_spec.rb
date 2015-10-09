require 'spec_helper'
require 'test_classes/cloud_searchable_test_class'

describe Cloudsearchable do
  let(:clazz){ CloudSearchableSampleClassFactory.call }

  it 'can describe an index that returns ids for the class type' do
    test_index = clazz.cloudsearch_index
    test_index.should be_kind_of(Cloudsearchable::Domain)
    expect(test_index.fields.size).to eq(4)
  end

  it 'has a default index' do
    clazz.cloudsearch_index.should be_kind_of(Cloudsearchable::Domain)
    clazz.cloudsearch_index(:test_index).should_not be(clazz.cloudsearch_index)
  end

  it 'names domains consistent with CloudSearch limitations' do
    clazz.cloudsearch_index(:test_index).name.should =~ /^[a-z][a-z0-9\-]+$/
  end

  describe 'an ordinary object' do
    #An instance of the searchable class
    let(:inst) do
      inst = clazz.new
      #arbitrary but plausible values for the core fields
      inst.destroyed = false
      inst.id = 42
      inst.lock_version = 18
      inst.customer = OpenStruct.new :id => 123
      inst.name = "My Name"
      inst
    end

    it 'supplies the right values to the fields' do
      test_index = clazz.cloudsearch_index
      test_index.fields[:test_class_id].value_for(inst).should be(inst.id)
      test_index.fields[:customer_id].value_for(inst).should   be(inst.customer)
      test_index.fields[:test_name].value_for(inst).should     be(inst.name)
      test_index.fields[:helpfulness].value_for(inst).should   be(1234)
    end

    it 'reindexes when told to' do
      clazz.cloudsearch_index(           ).should_receive(:post_record).with(inst, inst.id, inst.lock_version)
      clazz.cloudsearch_index(:test_index).should_receive(:post_record).with(inst, inst.id, inst.lock_version)
      inst.update_indexes
    end

    it 'generates a sensible addition sdf document' do
      sdf = clazz.cloudsearch_index.send :addition_sdf, inst, inst.id, inst.lock_version
      sdf[:fields][:helpfulness].should be(1234)
    end
  end

  describe 'a destroyed object' do
    #An instance of the searchable class
    let(:inst) do
      inst = clazz.new
      #arbitrary but plausible values for the core fields
      inst.destroyed = true
      inst
    end

    it 'reindexes when told to' do
      clazz.cloudsearch_index(           ).should_receive(:delete_record).with(inst.id, inst.lock_version)
      clazz.cloudsearch_index(:test_index).should_receive(:delete_record).with(inst.id, inst.lock_version)
      inst.update_indexes
    end
  end

end
