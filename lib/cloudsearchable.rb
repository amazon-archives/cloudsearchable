require 'cloudsearchable/version'

require 'cloudsearchable/domain'
require 'cloudsearchable/field'
require 'cloudsearchable/query_chain'
require 'cloudsearchable/cloud_search'
require 'cloudsearchable/config'

require 'active_support/inflector'
require 'active_support/core_ext/string'

module Cloudsearchable
  def self.configure
    block_given? ? yield(Cloudsearchable::Config) : Cloudsearchable::Config
  end

  def self.config
    configure
  end

  def self.logger
    Cloudsearchable::Config.logger
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def cloudsearch_domains= *args
    self.class.cloudsearch_domains = args
  end

  def cloudsearch_domains
    self.class.cloudsearch_domains
  end

  def update_indexes
    if destroyed?
      remove_from_indexes
    else
      add_to_indexes
    end
  end

  def add_to_indexes
    cloudsearch_domains.map do |name, domain|
      domain.post_record(self, id, lock_version)
    end
  end

  def remove_from_indexes
    cloudsearch_domains.map do |name, domain|
      domain.delete_record(id, lock_version)
    end
  end

  protected

  class DSL
    attr_reader :domain, :base

    def initialize domain, base
      @domain = domain
      @base = base
    end

    def uint name, options = {}, &block
      field name, :uint, options, &block
    end

    def text name, options = {}, &block
      field name, :text, options, &block
    end

    def literal name, options = {}, &block
      field name, :literal, options, &block
    end

    def field name, type, options = {}, &block
      # This block is executed in the context of the record
      if block_given?
        options[:source] = block.to_proc
      end
      domain.add_field name, type, options
    end
  end

  module ClassMethods
    def cloudsearch_domains= domains
      @cloudsearch_domains = domains
    end

    def cloudsearch_domains
      @cloudsearch_domains || {}
    end

    #
    # Declares a Cloudsearchable index that returns a list of object of this class.
    #
    # @param name (optional) optional name for the index. If not specified, a default (unnamed) index for the class will be created
    # @param options (optional) Hash defining an index
    #
    # @option options [String] :name Name of the index
    #
    #
    def index_in_cloudsearch(name = nil, &block)
      locator_field = :"#{cloudsearch_prefix.singularize}_id"
      # Fetches the existing search domain, or generates a new one
      unless domain = cloudsearch_domains[name]
        domain = new_cloudsearch_index(name).tap do |d|
          # This id field is used to reify search results
          d.add_field(locator_field, :literal,
            :result_enabled => true, :search_enabled => true,
            :source => :id)
        end
        self.cloudsearch_domains = self.cloudsearch_domains.merge({name => domain})
      end

      if block_given?
        dsl = DSL.new(domain, self)
        dsl.instance_exec &block
      end

      # Define the search method
      search_method_name = "search#{name && ('_' + name.to_s)}".to_sym
      define_singleton_method search_method_name do
        Query.new(self, cloudsearch_index(name), locator_field)
      end
    end

    def cloudsearch_index name = nil
      cloudsearch_domains[name]
    end

    #
    # Prefix name used for indexes, defaults to class name underscored
    #
    def cloudsearch_prefix
      name.pluralize.underscore.gsub('/', '_')
    end

    def new_cloudsearch_index name
      name = [cloudsearch_prefix, name].compact.join('-').gsub('_','-')
      Cloudsearchable::Domain.new name
    end

    # By default use 'find' to materialize items
    def materialize_method method_name = nil
      @materialize_method = method_name unless method_name.nil?
      @materialize_method.nil? ? :find : @materialize_method
    end
  end

  #
  # Wraps a Cloudsearchable::QueryChain, provides methods to execute and reify
  # a query into search result objects
  #
  class Query
    include Enumerable

    attr_reader :query, :class

    #
    # @param clazz [ActiveRecord::Model] The class of the Model object that
    #        is being searched. The result set will be objects of this type.
    # @param domain [Domain] Cloudsearchable Domain to search
    # @param identity_field [Symbol] name of the field that contains the id of
    #                                the clazz (e.g. :collection_id)
    #
    def initialize(clazz, domain, identity_field)
      @query = Cloudsearchable::QueryChain.new(domain, fatal_warnings: Cloudsearchable.config.fatal_warnings)
      @class = clazz
      @query.returning(identity_field)
      @identity_field = identity_field
    end

    [:where, :text, :order, :limit, :offset, :returning].each do |method_name|
      # Passthrough methods, see CloudSearch::Domain for docs
      define_method method_name do |*args|
        @query.send(method_name, *args)
        self
      end
    end

    # Pass through to Cloudsearchable::Domain#materialize!, then retrieve objects from database
    # TODO: this does NOT preserve order!
    def materialize!(*args)
      @results ||= begin
        record_ids = @query.map{|result_hit| result_hit['data'][@identity_field.to_s].first}.reject{|r| r.nil?}
        @class.send(@class.materialize_method, record_ids)
      end
    end

    def each &block
      # Returns an enumerator
      return enum_for(__method__) unless block_given?
      materialize!
      @results.respond_to?(:each) ? @results.each { |o| yield o } : [@results].send(:each, &block)
    end

    def found_count
      query.found_count
    end

  end
end
