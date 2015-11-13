require 'spec_helper'
require 'test_classes/cloud_searchable_test_class'

describe Cloudsearchable do
  let(:clazz){ CloudSearchableSampleClassFactory.call }

  it 'can describe an index that returns ids for the class type' do
    test_index = clazz.cloudsearch_index
    expect(test_index).to be_a(Cloudsearchable::Domain)
    expect(test_index.fields.count).to eq 4 #3 explicit + 1 for the id of the object
  end
  
  it 'has a default index' do
    expect(clazz.cloudsearch_index).to be_a(Cloudsearchable::Domain)
    expect(clazz.cloudsearch_index(:test_index)).to_not eq(clazz.cloudsearch_index)
  end
  
  it 'names domains consistent with CloudSearch limitations' do
    expect(clazz.cloudsearch_index(:test_index).name).to be =~ /^[a-z][a-z0-9\-]+$/
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
      expect(test_index.fields[:test_class_id].value_for(inst)).to eq(inst.id)
      expect(test_index.fields[:customer_id].value_for(inst)).to eq(inst.customer)
      expect(test_index.fields[:test_name].value_for(inst)).to eq (inst.name)
      expect(test_index.fields[:helpfulness].value_for(inst)).to eq(1234)
    end
    
    it 'reindexes when told to' do
      expect(clazz.cloudsearch_index(           )).to receive(:post_record).with(inst, inst.id, inst.lock_version)
      expect(clazz.cloudsearch_index(:test_index)).to receive(:post_record).with(inst, inst.id, inst.lock_version)
      inst.update_indexes
    end
    
    it 'generates a sensible addition sdf document' do
      sdf = clazz.cloudsearch_index.send :addition_sdf, inst, inst.id, inst.lock_version
      expect(sdf[:fields][:helpfulness]).to eq(1234)
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
      expect(clazz.cloudsearch_index(           )).to receive(:delete_record).with(inst.id, inst.lock_version)
      expect(clazz.cloudsearch_index(:test_index)).to receive(:delete_record).with(inst.id, inst.lock_version)
      inst.update_indexes
    end
  end

end
