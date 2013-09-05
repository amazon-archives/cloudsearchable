module Cloudsearchable
  class NoClausesError < StandardError; end
  class WarningInQueryResult < StandardError; end

  #
  # An object that represents a query to cloud search
  #
  class QueryChain
    include Enumerable
    
    attr_reader :domain, :fields

    # options:
    #   - fatal_warnings: if true, raises a WarningInQueryResult exception on warning. Defaults to false
    def initialize(domain, options = {})
      @fatal_warnings = options.fetch(:fatal_warnings, false)
      @domain         = domain
      @q              = nil
      @clauses        = []
      @rank           = nil
      @limit          = 100000 # 10 is the CloudSearch default, 2kb limit will probably hit before this will
      @offset         = nil
      @fields         = Set.new
      @results        = nil
    end
    
    #
    # This method can be called in several different forms. 
    #
    # To do an equality search on several fields, you can pass a single hash, e.g.:
    #
    #   Collection.search.where(customer_id: "12345", another_field: "Some value")
    #
    # To do a search on a single field, you can pass three parameters in the 
    # form: where(field, op, value)
    #
    #   Collection.search.where(:customer_id, :==, 12345)
    #
    # To search for any of several possible values for a field, use the :any operator:
    #
    #   Collection.search.where(:product_group, :any, %w{gl_kitchen gl_grocery})
    #
    # Equality and inequality operators (:==, :!=, :<, :<=, :>, :>=) are supported on
    # integers, and equality operators are supported on all scalars.
    # Currently, special operators against arrays (any and all) are not yet implemented.
    #
    def where(field_or_hash, op = nil, value = nil)
      raise if materialized?

      if field_or_hash.is_a? Hash
        field_or_hash.each_pair do |k, v| 
          where(k, :==, v)
        end
      elsif field_or_hash.is_a? Symbol
        field = field_or_hash
        @clauses << if op == :within_range
                      "#{field}:#{value.to_s}"
                    elsif op == :== || op == :eq
                      "#{field}:'#{value.to_s}'"
                    elsif op == :any
                      '(or ' + value.map { |v| "#{field}:'#{v.to_s}'" }.join(' ') + ')'
                    elsif op == :!=
                      "(not #{field}:'#{value.to_s}')"
                    elsif op == :> && value.is_a?(Integer)
                      "#{field}:#{value+1}.."
                    elsif op == :< && value.is_a?(Integer)
                      "#{field}:..#{value-1}"
                    elsif op == :>= && value.is_a?(Integer)
                      "#{field}:#{value}.."
                    elsif op == :<= && value.is_a?(Integer)
                      "#{field}:..#{value}"
                    else
                      raise "op #{op} is unrecognized"
                    end
      else
        raise "field_or_hash must be a Hash or Symbol, not a #{field_or_hash.class}"
      end

      self
    end

    #
    # Allows searching by text, overwriting any existing text search.
    #
    #   Collection.search.text('mens shoes')
    #
    # For more examples see http://docs.aws.amazon.com/cloudsearch/latest/developerguide/searching.text.html
    #
    def text(text)
      raise if materialized?
      @q = text
      self
    end

    #
    # Set a rank expression on the query, overwriting any existing expression. Defaults to "-text_relevance"
    #
    #   Collection.search.order('created_at')  # order by the created_at field ascending
    #   Collection.search.order('-created_at') # descending order
    #
    # For more examples see http://docs.amazonwebservices.com/cloudsearch/latest/developerguide/tuneranking.html
    #
    def order rank_expression
      raise if materialized?
      raise "order clause must be a string, not a #{rank_expression.class}" unless rank_expression.is_a? String
      @rank = rank_expression.to_s
      self
    end

    #
    # Limit the number of results returned from query to the given count.
    #
    #   Collection.search.limit(25)
    #
    def limit count
      raise if materialized?
      raise "limit value must be must respond to to_i, #{count.class} does not" unless count.respond_to? :to_i
      @limit = count.to_i
      self
    end

    #
    # Offset the results returned by the query by the given count.
    #
    #   Collection.search.offset(250)
    #
    def offset count
      raise if materialized?
      raise "limit value must be must respond to to_i, #{count.class} does not" unless count.respond_to? :to_i
      @offset = count.to_i
      self
    end

    #
    # Adds a one or more fields to the returned result set, e.g.:
    #   
    #   my_query.returning(:collection_id)
    #   my_query.returning(:collection_id, :created_at)
    #
    #   x = [:collection_id, :created_at]
    #   my_query.returning(x)
    #
    def returning(*fields)
      raise if materialized?

      fields.flatten!
      fields.each do |f|
        @fields << f
      end
      self
    end
    
    #
    # True if the query has been materialized (e.g. the search has been 
    # executed). 
    #
    def materialized?
      !@results.nil?
    end
    
    #
    # Executes the query, getting a result set, returns true if work was done,
    # false if the query was already materialized.
    # Raises exception if there was a warning and not in production.
    #
    def materialize!
      return false if materialized?
      
      @results = domain.execute_query(to_q)

      if @results && @results["info"] && messages = @results["info"]["messages"]
        messages.each do |message|
          if message["severity"] == "warning"
            Cloudsearchable.logger.warn "Cloud Search Warning: #{message["code"]}: #{message["message"]}"
            raise(WarningInQueryResult, "#{message["code"]}: #{message["message"]}") if @fatal_warnings
          end
        end
      end

      true
    end

    def found_count
      materialize!
      if @results['hits']
        @results['hits']['found']
      else
        raise "improperly formed response. hits parameter not available. messages: #{@results["messages"]}"
      end
    end
    
    def each(&block)
      materialize!
     if @results['hits']
       @results['hits']['hit'].each(&block)
     else
       raise "improperly formed response. hits parameter not available. messages: #{@results["messages"]}"
     end
    end
    
    #
    # Turns this Query object into a query string hash that goes on the CloudSearch URL
    #
    def to_q
      raise NoClausesError, "no search terms were specified" if (@clauses.nil? || @clauses.empty?) && (@q.nil? || @q.empty?)
      
      bq = (@clauses.count > 0) ? "(and #{@clauses.join(' ')})" : @clauses.first
      {
        q: @q,
        bq: bq,
        rank: @rank,
        size: @limit,
        start: @offset,
        :'return-fields' => @fields.reduce("") { |s,f| s << f.to_s }
      }
    end
  end
end
