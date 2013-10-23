#
# Class the represents the schema of a domain in CloudSearch
#
# In general, it will be instantiated by a helper class or module, like Cloudsearch_enabled.
#
module Cloudsearchable
  class Domain
    class DomainNotFound < StandardError; end

    attr_reader :name, :fields

    def initialize name
      @name = "#{Cloudsearchable::Config.domain_prefix}#{name}"
      @fields = {}
    end

    # Defines a literal index field.
    # @param name field name
    # @param type field type - one of :literal, :uint, or :text
    # @option options [Boolean] :search_enabled (true)
    # @option options [Boolean] :return_enabled (true)
    # @option options [Symbol or Proc] :source The name of a method to call on a record to fetch
    #   the value of the field, or else a Proc to be evaluated in the context of the record.
    #   Defaults to a method with the same name as the field.
    def add_field(name, type, options = {})
      field = Field.new(name, type, options)
      raise "Field #{name} already exists on index #{self.name}" if @fields.has_key?(field.name)
      @fields[field.name] = field
    end

    # Creates the domain and defines its index fields in Cloudsearch
    # Will blindly recreate index fields, no-op if the index already exists
    def create
      Cloudsearchable.logger.info "Creating domain #{name}"
      CloudSearch.client.create_domain(:domain_name => name)
    
      #Create the fields for the index
      fields.values.each do |field| 
        Cloudsearchable.logger.info "  ...creating #{field.type} field #{name}"
        field.define_in_domain self.name
      end
      Cloudsearchable.logger.info "  ...done!"
    end

    def reindex
      CloudSearch.client.index_documents(:domain_name => name)
    end
    
    #
    # This queries the status of the domain from Cloudsearch and determines if 
    # the domain needs to be reindexed. If so, it will initiate the reindex and
    # wait timeout seconds for it to complete. Default is 0. Reindexings tend
    # to take 15-30 minutes. 
    #
    # @return true if the changes are applied, false if the domain is still reindexing
    #
    def apply_changes(timeout = 0)
      d = cloudsearch_domain(true)[:domain_status_list][0]
      if(d[:requires_index_documents])
        reindex
      end
      
      #We'll potentially sleep until the reindex has completed
      end_time = Time.now + timeout
      sleep_time = 1
      loop do
        d = cloudsearch_domain(true)[:domain_status_list][0]
        break unless (d[:processing] && Time.now < end_time)
        
        sleep(sleep_time)          
        sleep_time = [2 * sleep_time, end_time - Time.now].min #exponential backoff
      end
      
      !d[:processing] #processing is true as long as it is reindexing
    end

    # Add or replace the CloudSearch document for a particular version of a record
    def post_record record, record_id, version
      ActiveSupport::Notifications.instrument('cloudsearchable.post_record') do
        CloudSearch.post_sdf doc_endpoint, addition_sdf(record, record_id, version)
      end
    end

    # Delete the CloudSearch document for a particular record (version must be greater than the last version pushed)
    def delete_record record_id, version
      ActiveSupport::Notifications.instrument('cloudsearchable.delete_record') do
        CloudSearch.post_sdf doc_endpoint, deletion_sdf(record_id, version)
      end
    end

    def execute_query(params)
      uri    = URI("http://#{search_endpoint}/#{CloudSearch::API_VERSION}/search")
      uri.query = URI.encode_www_form(params)
      Cloudsearchable.logger.info "CloudSearch execute: #{uri.to_s}"
      res = ActiveSupport::Notifications.instrument('cloudsearchable.execute_query') do
        Net::HTTP.get_response(uri).body
      end
      JSON.parse(res)
    end

    def deletion_sdf record_id, version
      {
        :type    => "delete",
        :id      => document_id(record_id),
        :version => version
      }
    end

    def addition_sdf record, record_id, version
      {
        :type    => "add",
        :id      => document_id(record_id),
        :version => version,
        :lang    => "en", # FIXME - key off of marketplace
        :fields  => sdf_fields(record)
      }
    end

    # Generate a documentID that follows the CS restrictions
    def document_id record_id
      Digest::MD5.hexdigest record_id.to_s
    end

    protected

    #
    # AWS Cloudsearchable Domain
    #
    # @param force_reload force a re-fetch from the domain
    #
    def cloudsearch_domain(force_reload = false)
      if(force_reload || !@domain)
        @domain = ActiveSupport::Notifications.instrument('cloudsearchable.describe_domains') do
          CloudSearch.client.describe_domains(:domain_names => [name])
        end
      else
        @domain
      end

      status = @domain[:domain_status_list]
      if status.nil? || status && status.empty?
        raise(DomainNotFound, "Cloudsearchable could not find the domain '#{name}' in AWS. Check the name and the availability region.")
      end

      @domain
    end

    def sdf_fields record
      fields.values.inject({}) do |sdf, field|
        value = field.value_for(record)
        sdf[field.name] = value if value
        sdf
      end
    end

    # AWS CloudSearch Domain API to get search endpoint
    def search_endpoint
      @search_endpoint ||= cloudsearch_domain[:domain_status_list].first[:search_service][:endpoint]
    end

    # AWS CloudSearch Domain API to get doc endpoint
    def doc_endpoint
      @doc_endpoint ||= cloudsearch_domain[:domain_status_list].first[:doc_service][:endpoint]
    end

  end
end
