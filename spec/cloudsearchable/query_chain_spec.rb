require 'spec_helper'
require 'test_classes/cloud_searchable_test_class'

describe Cloudsearchable::Query do
  let(:clazz){ CloudSearchableSampleClassFactory.call }

  it "doesn't build queries without a query term" do
    expect do
      query = clazz.search.limit(10).query.to_q
    end.to raise_exception
  end

  describe '#where' do
    it 'can build a simple search query' do
      query = clazz.search.where(:customer_id, :eq, 'A1234').query.to_q[:bq]
      expect(query).to match /customer_id:'A1234'/
    end

    it 'rejects field names that were not defined in the index' do
      expect { clazz.search.where(:mispeled_field, :eq, 12345) }.to raise_exception
    end

    it 'chains' do
      query = clazz.search.where(customer_id: 'A1234').where(helpfulness: 42).query.to_q[:bq]
      expect(query).to match /customer_id:'A1234'/
      expect(query).to match /helpfulness:42/
    end

    it 'can build a query with "not equal to" condition' do
      query = clazz.search.where(:customer_id, :!=, 'A1234').query.to_q[:bq]
      expect(query).to match /\(not customer_id:'A1234'\)/
    end

    it 'can build a query from a hash' do
      query = clazz.search.where(customer_id: 'A1234', helpfulness: 42).query.to_q[:bq]
      expect(query).to match /customer_id:'A1234'/
      expect(query).to match /helpfulness:42/
    end

    context 'literal data type' do
      it 'supports equality' do
        query = clazz.search.where(:customer_id, :==, 'ABC').query.to_q[:bq]
        expect(query).to eq "customer_id:'ABC'"
      end

      it 'supports :any' do
        query = clazz.search.where(:customer_id, :any, ['ABC', 'DEF']).query.to_q[:bq]
        expect(query).to eq "(or customer_id:'ABC' customer_id:'DEF')"
      end

      it 'accepts a value as an integer' do
        expect(clazz.search.where(customer_id: 123).query.to_q[:bq]).to match /customer_id:'123'/
      end

      it 'rejects nil value' do
        expect { clazz.search.where(customer_id: nil) }.to raise_exception
      end
    end

    context 'uint data type' do
      it 'supports range query' do
        query = clazz.search.where(:helpfulness, :within_range, "0..#{123}").query.to_q[:bq]
        expect(query).to match /helpfulness:0..123/
      end

      it 'supports range query using a ruby range' do
        query = clazz.search.where(:helpfulness, :within_range, 0..123).query.to_q[:bq]
        expect(query).to match /helpfulness:0..123/
      end

      it 'supports equality' do
        query = clazz.search.where(:helpfulness, :==, 123).query.to_q[:bq]
        expect(query).to eq 'helpfulness:123'
      end

      it 'supports not-equality' do
        query = clazz.search.where(:helpfulness, :!=, 123).query.to_q[:bq]
        expect(query).to eq '(not helpfulness:123)'
      end

      it 'supports greater-than' do
        query = clazz.search.where(:helpfulness, :>, 123).query.to_q[:bq]
        expect(query).to match /helpfulness:124../
      end

      it 'supports greater-than-or-equal-to' do
        query = clazz.search.where(:helpfulness, :>=, 123).query.to_q[:bq]
        expect(query).to match /helpfulness:123../
      end

      it 'supports less-than' do
        query = clazz.search.where(:helpfulness, :<, 123).query.to_q[:bq]
        expect(query).to match /helpfulness:..122/
      end

      it 'supports less-than-or-equal-to' do
        query = clazz.search.where(:helpfulness, :<=, 123).query.to_q[:bq]
        expect(query).to match /helpfulness:..123/
      end

      it 'supports :any' do
        query = clazz.search.where(:helpfulness, :any, [123, 456]).query.to_q[:bq]
        expect(query).to match '(or helpfulness:123 helpfulness:456)'
      end

      it 'accepts a value as a string' do
        query = clazz.search.where(helpfulness: '123').query.to_q[:bq]
        expect(query).to match /helpfulness:123/
      end

      [Object.new, nil, '123a'].each do |v|
        it "rejects value #{v} of type #{v.class}" do
          expect { clazz.search.where(helpfulness: v) }.to raise_exception
        end
      end
    end

    [:>, :>=, :<, :<=].each do |op|
      [Object.new, nil, '123a'].each do |v|
        it "does not permit op #{op} on value #{v} of type #{v.class}" do
          expect { clazz.search.where(:helpfulness, op, v).query.to_q[:bq] }.to raise_error
        end
      end
    end
  end


  it 'supports querying for any of several values of a field' do
    expect(clazz.search.where(:test_name, :any, %w{big small}).query.to_q[:bq]).to include("(or test_name:'big' test_name:'small')")
  end

  it 'supports text method' do
    query = clazz.search.text('test').query.to_q[:q]
    expect(query).to match /test/
  end

  it 'supports chaining text and where clauses together' do
    query = clazz.search.text('test').where(:helpfulness, :==, 123).query
    expect(query.to_q[:q]).to  match /test/
    expect(query.to_q[:bq]).to match /helpfulness:123/
  end

  it 'supports ordering with a rank expression' do
    expect(clazz.search.where(customer_id: 12345).order('-helpfulness').query.to_q[:rank]).to eq '-helpfulness'
  end

  it 'supports limit' do
    expect(clazz.search.where(customer_id: 12345).limit(10).query.to_q[:size]).to eq 10
  end

  it 'has high default limit' do
    expect(clazz.search.where(customer_id: 12345).query.to_q[:size]).to eq 100000
  end

  it 'supports offset' do
    expect(clazz.search.where(customer_id: 12345).offset(100).query.to_q[:start]).to eq 100
  end

  context 'queries' do
    before(:each) do
      allow(clazz.cloudsearch_index).to receive(:execute_query).and_return(cloudsearch_response)
    end

    context 'query warning' do
      before(:each) do
        allow(clazz).to receive(:find).and_return([])
        expect(Cloudsearchable.logger).to receive(:warn).with(/CS-InvalidFieldOrRankAliasInRankParameter/)
      end

      let(:query){clazz.search.where(customer_id: 12345).order("-adult")}
      let(:cloudsearch_response) do
        # generated by ranking a literal field that is search-enabled but not result-enabled
        {
            "rank" => "adult",
            "match-expr" => "(label initialized_at:1363464074..1366056074)",
            "hits" => {
                "found" => 285,
                "start" => 0,
                "hit" => [
                    {"id" => "40bdd5072b6dbae6245fe4ee837d22e3","data" => {"test_class_id" => ["PCxSz65GIcZTtc0UpRdT-i--w-1365550370"]}},
                    {"id" => "00af8f5f96aa1db7aff77be5651b3bb1","data" => {"test_class_id" => ["PCxhksJTLRYnoGXvwZik82Fkw-1365020313"]}},
                    {"id" => "00b6ac84e3ae402e7698959bf692a53e","data" => {"test_class_id" => ["PCxs-fIVZnBcTzZ4MtfDguS1A-1365020274"]}},
                    {"id" => "018fdee653bff74abd12ac30152a2837","data" => {"test_class_id" => ["PCxmAGHFtAgyqUrgI3HgM_P6Q-1365548349"]}},
                    {"id" => "01d062d24c389906eea2d16b8193eb56","data" => {"test_class_id" => ["PCxqjaTmwydKM82NqymbryNfg-1365470479"]}},
                    {"id" => "01e3ee5d848a30385a4e90eb851b094d","data" => {"test_class_id" => ["PCxSz65GIcZTtc0UpRdT-i--w-1365550369"]}},
                    {"id" => "01fca44cc596adb295ca6ee9f9f36499","data" => {"test_class_id" => ["PCx7XKbKwOVf1VvEWvTl5c1Eg-1365020176"]}},
                    {"id" => "02b85c9835b5045065ee389954a60c5f","data" => {"test_class_id" => ["PCxp_xid_WeTfTmb5MySEfxhQ-1365115565"]}},
                    {"id" => "040c01be434552a1d9e99eef9db87bdd","data" => {"test_class_id" => ["PCxLOYzA4bCt7-bP6wsZnl-ow-1365020297"]}},
                    {"id" => "048567c755e30d6d64d757508f1feaa0","data" => {"test_class_id" => ["PCxJhhnpYkeSKrOxteQo5Jckw-1365115667"]}}
                ]
            },
            "info" => {
                "rid" => "7df344e77e1076a903e1f2dc1effcf3dde0a89442fb459d00a6e60ac64b8bbfcab1fbc5b35c10949",
                "time-ms" => 3,
                "cpu-time-ms" => 0,
                "messages" => [
                    {
                        "severity" => "warning",
                        "code" => "CS-InvalidFieldOrRankAliasInRankParameter",
                        "host" => "7df344e77e1076a9884a6c43665da57c",
                        "message" => "Unable to create score object for rank 'adult'"
                    }
                ]
            }
        }
      end

      it 'causes WarningInQueryResult exception' do
        expect(lambda{ query.to_a }).to raise_error(Cloudsearchable::WarningInQueryResult)
      end

      it 'takes a :fatal_warnings option, and when set to false, does not raise' do
        sample_query = Cloudsearchable::QueryChain.new(double, fatal_warnings: false)
        expect(sample_query.instance_variable_get(:@fatal_warnings)).to be false

        q = query
        q.query.instance_variable_set(:@fatal_warnings, false)
        expect(lambda{ q.to_a }).not_to raise_error
      end
    end

    context 'valid query results' do
      let(:customer_id){ '12345' }
      let(:other_customer_id){ 'foo' }

      let(:cloudsearch_response) do
        {
            "rank"=>"-text_relevance",
            "match-expr"=>"(label customer_id:'12345')",
            "hits"=>{
                "found"=>11,
                "start"=>0,
                "info"=>{
                    "rid"=>"e2467862eecf73ec8dfcfe0cba1893abbe2e8803402f4da65b1195593c0f78ec3e8f1d29f6e40723",
                    "time-ms"=>2,
                    "cpu-time-ms"=>0
                },
                "hit"=>[
                    {"id"=>"0633e1c9793f5288c58b664356533e81", "data"=>{"test_class_id"=>["ANINSTANCEID"]}},
                # {"id"=>"04931ebede796ae8b435f1fd5291e772", "data"=>{"test_class_id"=>["PCxTj26ZRmV_EnHigQWx0S06w"]}},
                # {"id"=>"72159a172d3043bfcdadb5244862b9ee", "data"=>{"test_class_id"=>["PCxS_apFtZMrKuqyPhFNstzMQ"]}},
                # {"id"=>"1eb815b075bc005e97dc5827e53b9615", "data"=>{"test_class_id"=>["PCxSksjDUBehPWhYYW2Dtj4KQ"]}},
                # {"id"=>"3e4950b829456b13bf1460b25a7aca26", "data"=>{"test_class_id"=>["PCx1oiyh6vrHGSeLvis4USMfQ"]}},
                # {"id"=>"00b441f55fff86d2d746227988da77a9", "data"=>{"test_class_id"=>["PCxpt-aW8topsnTGs-AIkzWCA"]}},
                # {"id"=>"919ea27d21bbdc07ead4688a0d7ceca1", "data"=>{"test_class_id"=>["PCxFHGLbGJ2mzau_a6-gh5ORw"]}},
                # {"id"=>"c663c2d9af342b0038fc808322143cfd", "data"=>{"test_class_id"=>["PCxyFwShwjWBp_WiXB0rFb2WA"]}},
                # {"id"=>"de8f00af5636393e2553c4b4710d3393", "data"=>{"test_class_id"=>["PCxnqXfm8McflBgi4HsYoUXVw"]}},
                # {"id"=>"e297cf21741a4c43697ea2586164a987", "data"=>{"test_class_id"=>["PCxrdk8gAEVbkuUCazu2-qLjQ"]}}
                ]
            }
        }
      end

      it 'materializes' do
        allow(clazz).to receive(:find).with(["ANINSTANCEID"]).and_return([customer_id])
        query = clazz.search.where(customer_id: 12345)
        expect(query.to_a).to eq [customer_id]
      end

      it 'materializes db results only once' do
        expected_results = [customer_id, other_customer_id]
        allow(clazz).to receive(:find).once.and_return(expected_results)

        query = clazz.search.where(customer_id: 12345)
        query.materialize!
        query.materialize!
      end

      it 'should not materialize if only asking for found_count' do
        expect(clazz).not_to receive(:find)
        clazz.search.where(customer_id: 12345).found_count
      end

      it 'supports each for multiple results' do
        expected_results = [customer_id, other_customer_id]
        expect(clazz).to receive(:find).with(["ANINSTANCEID"]).and_return(expected_results)

        results = clazz.search.where(customer_id: 12345).to_a
        (0..results.length).each{ |i| expect(results[i]).to eq expected_results[i] }
      end

      it 'supports each for single results' do
        expect(clazz).to receive(:find).with(["ANINSTANCEID"]).and_return(customer_id)

        results = clazz.search.where(customer_id: 12345).to_a
        results.each{ |r| expect(r).to eq customer_id }
      end

      it 'supports each for nil result' do
        expect(clazz).to receive(:find).with(["ANINSTANCEID"]).and_return(nil)

        results = clazz.search.where(customer_id: 12345).to_a
        results.each{ |r| expect(r).not_to be }
      end

      it 'uses materialized method' do
        expect(clazz).to receive(:another_find).with(["ANINSTANCEID"]).and_return(customer_id)
        clazz.materialize_method :another_find
        clazz.search.where(customer_id: 12345).to_a
      end

      it 'returns the correct found count' do
        expect(clazz.search.where(customer_id: 12345).found_count).to eq 11
      end
    end

    context 'invalid query results' do
      let(:cloudsearch_response) do
        {
            "error"=>"info",
            "rid"=>"6ddcaa561c05c4cc85ddb10cb46568af2ef64b0583910e32210f551c238586e40fc3abe629ca87b250796d395a628af6",
            "time-ms"=>20,
            "cpu-time-ms"=>0,
            "messages"=>[
                {
                    "severity"=>"fatal",
                    "code"=>"CS-UnknownFieldInMatchExpression",
                    "message"=>"Field 'asdf' is not defined in the metadata for this collection."
                }
            ]
        }
      end

      it 'raises an exception when requesting found count with an error response' do
        expect { clazz.search.where(customer_id: 12345).found_count }.to raise_error
      end
    end

    context 'empty results with non-empty data' do
      let(:cloudsearch_response) do
        {
            # Empty-yet-present data may occur with a NOT query, such as "(not customer_id:'XYZ')".
            # Refer to: https://aws.amazon.com/support/case?caseId=107084141&language=en
            "rank" => "-text_relevance",
            "match-expr" => "(not customer_id:'A3E4T85Q6WPY4F')",
            "hits" => {
                "found" => 2087,
                "start" => 0,
                "hit" => [
                    {"id" => "fb9fb53e32c4b3714cf39be4b855d34b", "data" => { "test_class_id" => []}},
                ]
            },
            "info" => {
                "rid" => "621cf310b88f32076b1908e45b4930aafb872497bdbf3b5e64065619c0dcec96bbe513281093d6c7",
                "time-ms" => 3,
                "cpu-time-ms" => 0
            }
        }
      end

      it 'does not raise an exception' do
        expect(clazz).to receive(:find).with([]).and_return(nil)
        clazz.search.where(:customer_id, :!=, 'ABCDE')
        expect { clazz.search.where(:customer_id, :!=, 'ABCDE').to_a }.to_not raise_error
      end
    end
  end

end
