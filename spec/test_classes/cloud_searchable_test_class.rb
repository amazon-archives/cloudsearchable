require 'ostruct'
require 'active_model'

# A class that includes Cloudsearchable
CloudSearchableSampleClassFactory = Proc.new do
  Class.new do
    include ActiveModel::Dirty
    extend ActiveModel::Callbacks
    define_model_callbacks :touch, :save

    # Your class must implement #id, #version, and #destroyed?
    attr_accessor :id, :customer, :name, :lock_version, :destroyed

    include Cloudsearchable

    # Anonymous classes don't have names, so set one:
    def self.name
      "TestClass"
    end

    def destroyed?
      !! @destroyed
    end

    # This is the default index. You probably only need one.
    index_in_cloudsearch do |idx|
      literal :id,          :searchable => true
    end

    # A named index.
    index_in_cloudsearch :test_index do |idx|
      # Fetch the customer_id field from customer
      literal :customer_id, :returnable => true,  :searchable => true, :source => Proc.new { customer }

      # Map the 'name' Ruby attribute to a field called 'test_name'
      text    :test_name,   :returnable => false, :searchable => true, :source => :name

      # uint fields can be used in result ranking functions
      uint    :helpfulness, :returnable => true,  :searchable => false do; 1234 end
    end
  end
end
