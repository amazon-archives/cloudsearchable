require 'spec_helper'
require 'test_classes/cloud_searchable_test_class'

describe Cloudsearchable::Domain do
  before(:each) do
    fake_client = double('client')
    allow(CloudSearch).to receive(:client).and_return(fake_client)
  end
  
  #
  # First call to describe_domains returns it needs reindexing, 
  # Second call returns that it is processing,
  # Third call returns that it is done processing
  #
  let(:needs_rebuild_domain) do
    described_class.new('nrb-index').tap do |dom|
      resp = describe_domain_response(dom.name)
      allow(CloudSearch.client).to receive(:describe_domains).with(:domain_names => [dom.name]).
        and_return(
          describe_domain_response(dom.name, :required_index_documents => true),
          describe_domain_response(dom.name, :processing => true),
          describe_domain_response(dom.name)
        )
    end
  end
  
  # A domain name named 'my-index'
  let(:domain) do
    described_class.new('my-index').tap do |dom|
      allow(CloudSearch.client).to receive(:describe_domains).and_return(describe_domain_response(dom.name))
      allow(CloudSearch.client).to receive(:describe_domains).with(:domain_names => [dom.name]).and_return(describe_domain_response(dom.name))
    end
  end

  let(:empty_domain) do
    described_class.new('my-index').tap do |dom|
      allow(CloudSearch.client).to receive(:describe_domains).and_return({})
    end
  end
  
  it 'can be instantiated' do
    index = domain
    expect(index.name).to end_with('my-index')
  end

  it 'can haz a literal field' do
    index = domain
    index.add_field(:literary, :literal) { nil }
    expect(index.fields[:literary].type).to eq(:literal)
  end

  it 'can be initialized with a nested class' do
    class OuterClassForCloudSearch
      class InnerClass
        include Cloudsearchable
      end
    end

    expect(OuterClassForCloudSearch::InnerClass.cloudsearch_prefix).to match(/^[A-Za-z0-9_-]+$/)
    Object.instance_eval { remove_const :OuterClassForCloudSearch }
  end
  
  context "SDF documents" do
    let(:object) { OpenStruct.new(:field_with_nil_value => nil, :field_with_present_value => 42) }
    subject do
      described_class.new('my-index').tap do |d|
        d.add_field(:field_with_nil_value, :literal)
        d.add_field(:field_with_present_value, :literal)
      end
    end
    
    it "generates present fields" do
      expect(subject.addition_sdf(object, "id", 1)[:fields][:field_with_present_value]).to eq 42
    end
    
    it "does not generate nil fields" do
      expect(subject.addition_sdf(object, "id", 1)[:fields][:field_with_nil_value]).to be_nil
    end
  end

  it 'raises if the domain cannot be found' do
    expect { empty_domain.send(:search_endpoint) }.to raise_error( Cloudsearchable::Domain::DomainNotFound,
                                                                   /Cloudsearchable could not find the domain/)
  end

  #
  # A test for the accidental clashing of domain caching
  # on a class variable
  #
  it 'caches endpoints for multiple domains' do
    expect(domain.send(:search_endpoint)).to_not eq(needs_rebuild_domain.send(:search_endpoint))
  end

  it 'endpoint selected is based on the domain name' do
    expect(domain.send(:search_endpoint)).to eq describe_domain_response(domain.name)[:domain_status_list][0][:search_service][:endpoint]
    expect(domain.send(:doc_endpoint)).to    eq describe_domain_response(domain.name)[:domain_status_list][0][:doc_service][:endpoint]
  end
  
  it 'sleeps, waiting for reindexing' do
    expect(CloudSearch.client).to receive(:index_documents).with(:domain_name => needs_rebuild_domain.name)
    expect(CloudSearch.client).to receive(:describe_domains).exactly(3).times
    expect(needs_rebuild_domain.apply_changes(3)).to be_truthy
  end

  protected
  
  #
  # A mockup of the response to a describe_domain request
  #
  def describe_domain_response(domain_name, options = {})
    {
      :domain_status_list=> [
        {
          :search_partition_count=>1, 
          :search_service=>{
            :arn=>"arn:aws:cs:us-east-1:510523556749:search/#{domain_name}", 
            :endpoint=>"search-#{domain_name}-7bq6utq4fdrwax5r6irje7xlra.us-east-1.cloudsearch.amazonaws.com"
          }, 
          :num_searchable_docs=>23,
          :search_instance_type=>"search.m1.small", 
          :created=>true, 
          :domain_id=>"510523556749/#{domain_name}", 
          :processing=> options.fetch(:processing, false), 
          :search_instance_count=>1, 
          :domain_name=>"#{domain_name}", 
          :requires_index_documents=> options.fetch(:required_index_documents,false), 
          :deleted=>false, 
          :doc_service=>{
            :arn=>"arn:aws:cs:us-east-1:510523556749:doc/#{domain_name}", 
            :endpoint=>"doc-#{domain_name}-7bq6utq4fdrwax5r6irje7xlra.us-east-1.cloudsearch.amazonaws.com"
          }
        },
        {:search_partition_count=>1,
         :search_service=>
          {:arn=>
            "arn:aws:cs:us-east-1:510523556749:search/dev-llarue-collection-items",
           :endpoint=>
            "search-dev-llarue-collection-items-hjopg2yzhcjdd4qxeglr2v5v7m.us-east-1.cloudsearch.amazonaws.com"},
         :num_searchable_docs=>2,
         :search_instance_type=>"search.m1.small",
         :created=>true,
         :domain_id=>"510523556749/dev-llarue-collection-items",
         :processing=>false,
         :search_instance_count=>1,
         :domain_name=>"dev-llarue-collection-items",
         :requires_index_documents=>false,
         :deleted=>false,
         :doc_service=>
          {:arn=>"arn:aws:cs:us-east-1:510523556749:doc/dev-llarue-collection-items",
           :endpoint=>
            "doc-dev-llarue-collection-items-hjopg2yzhcjdd4qxeglr2v5v7m.us-east-1.cloudsearch.amazonaws.com"}}
      ], 
      :response_metadata=>{
        :request_id=>"7d9487a7-1c9f-11e2-9f96-0958b8a97a74"
      }
    }
  end
end
