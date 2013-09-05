require 'active_support/core_ext/hash'

#
# Class the represents the schema of a domain in CloudSearch
#
# In general, it will be instantiated by a helper class or module, like Cloudsearch_enabled.
#
module Cloudsearchable
  # Represents a single field in a CloudSearch index.
  #
  class Field
    FieldTypes = [:literal, :uint, :text].freeze
    # Maps the type of field to the name of the options hash when defining the field
    FieldTypeOptionsNames = {:literal => :literal_options, :uint => :u_int_options, :text => :text_options}.freeze
    # Maps from field type to the allowed set of options for the field
    FieldTypeOptionsKeys = {
      literal: [:default_value, :facet_enabled, :search_enabled, :result_enabled].freeze,
      uint:    [:default_value].freeze,
      text:    [:default_value, :facet_enabled, :result_enabled].freeze
    }.freeze
    attr_reader :name, :type, :source, :options

    def initialize(name, type, options = {})
      raise ArgumentError, "Invalid field type '#{type}'" unless FieldTypes.include?(type)
      @name = name.to_sym
      @type = type.to_sym
      @source = options[:source] || @name
      @options = options.slice(*FieldTypeOptionsKeys[@type])
    end

    def value_for record
      if @source.respond_to?(:call)
        record.instance_exec &@source
      else
        record.send @source
      end
    end

    def define_in_domain domain_name
      CloudSearch.client.define_index_field(
        :domain_name => domain_name,
        :index_field => definition
      )
    end

    def definition
      # http://docs.amazonwebservices.com/cloudsearch/latest/developerguide/API_IndexField.html
      {
        :index_field_name => name.to_s, 
        :index_field_type => type.to_s,
        FieldTypeOptionsNames[type] => options
      }
    end
    protected :definition
  end
end
