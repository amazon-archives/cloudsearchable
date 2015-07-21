require 'spec_helper'
require 'test_classes/cloud_searchable_test_class'

describe CloudSearch do

  let(:item) do
    CloudSearchableSampleClassFactory.call.new.tap do |instance|
      instance.destroyed = false
      instance.lock_version = 1
      instance.id = 1
      instance.customer = '1234'
    end
  end
  let(:sdf_document){item.class.cloudsearch_index(:test_index).send :addition_sdf, item, item.id, item.lock_version}
  let(:endpoint){'https://fake_end_point.amazon.com'}

  class MockHTTPOK < Net::HTTPOK
    attr :body
    def initialize body
      @body = body
    end
  end

  class MockHTTPBadRequest < Net::HTTPBadRequest
    def initialize; end
  end

  let(:success_response){ MockHTTPOK.new( {"status" => "success", "adds" => 1, "deletes" => 0}.to_json ) }

  it 'json parses the response' do
    allow_any_instance_of(Net::HTTP).to receive(:start).and_return(success_response)

    response = described_class.post_sdf endpoint, sdf_document
    expect(response).to eq JSON.parse success_response.body
  end

  it 'triggers error! on response its no not a Net::HTTPSuccess' do
    response = MockHTTPBadRequest.new
    allow_any_instance_of(Net::HTTP).to receive(:start).and_return(response)

    expect(response).to receive(:error!)
    described_class.post_sdf endpoint, sdf_document
  end

end
