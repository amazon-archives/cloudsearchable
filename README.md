# Cloudsearchable
An ActiveRecord-style ORM query interface for AWS Cloud Search.

Note: this needs to be updated to work with the cloudsearch’s [2013-01-01 API](http://docs.aws.amazon.com/cloudsearch/latest/developerguide/migrating.html). If you update the gem please submit a pull request.

[![Build Status](https://travis-ci.org/awslabs/cloudsearchable.svg)](https://travis-ci.org/awslabs/cloudsearchable)

## Installation
Add to your Gemfile: gem 'cloudsearchable'. Run bundle or: gem install cloudsearchable.

## Usage
### 1. Mix Cloudsearchable into your class
```ruby
class Customer
  include Cloudsearchable

  attr_accessor :id, :customer, :name, :lock_version
  
  # This is the default index. You probably only need one.
  index_in_cloudsearch do |idx|
    # Fetch the customer_id field from customer
    literal :customer_id, :result_enabled => true,  :search_enabled => true, :source => Proc.new { customer }

    # Map the 'name' Ruby attribute to a field called 'test_name'
    text    :test_name,   :result_enabled => false, :search_enabled => true, :source => :name

    # uint fields can be used in result ranking functions
    uint    :helpfulness, :result_enabled => true,  :search_enabled => false do; 1234 end
  end

  # A named index.
  index_in_cloudsearch :test_index do |idx|
    literal :id,          :search_enabled => true
  end
end
```
### 2. Index some objects
```ruby
c = Customer.new
c.add_to_indexes
c.update_indexes
c.remove_from_indexes
```
### 3. Start querying
```ruby
Customer.search.where(customer_id: 12345)
Customer.search.where(customer_id: 12345).order('-helpfulness')  # ordering
Customer.search.where(customer_id: 12345).limit(10)              # limit, default 100000
Customer.search.where(customer_id: 12345).offset(100)            # offset
Customer.search.where(customer_id: 12345).found_count            # count

Customer.search.where(customer_id: 12345).where(helpfulness: 42) # query chain
Customer.search.where(customer_id: 12345, helpfulness: 42)       # query chain from hash
Customer.search.where(:category, :any, ["big", "small"])         # multiple values
Customer.search.where(:customer_id, :!=, 1234)                   # "not equal to" operator
Customer.search.text('test')                                     # text search
Customer.search.text('test').where(:featured, :==, 'f')          # text search with other fields

Customer.search.where(:helpfulness, :within_range, 0..123)       # uint range query, string range works too
Customer.search.where(:helpfulness, :>, 123)                     # uint greather than
Customer.search.where(:helpfulness, :>=, 123)                    # uint greather than or equal to
Customer.search.where(:helpfulness, :<, 123)                     # uint less than
Customer.search.where(:helpfulness, :<=, 123)                    # uint less than or equal to
```
These queries return a Cloudsearchable::Query, calling .to_a or .found_count will fetch the results
```ruby
Customer.search.where(customer_id: 12345).each |customer|
  p "#{customer.class}: #{customer.name}"
end
# Customer: foo
# Customer: bar
```
### Configuration
```ruby
# config\initializers\cloudsearchable_config.rb

require 'cloudsearchable'

Cloudsearchable.configure do |config|
  config.domain_prefix = "dev-lane-"
end
```
Supported Options
* domain_prefix - A name prefix string for your domains in CloudSearch. Defaults to Rails.env, or "" if Rails is undefined.
* config.fatal_warnings - raises WarningInQueryResult exception on warning. Defaults to false.
* config.logger - a custom logger, defaults to Rails if defined.

### ActiveSupport Notifications

Requests to AWS cloudsearch are instrumented using [ActiveSupport Notifications](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html). To consume these instrumented events register a subscriber in your Application. For example, to register for getting notifications for search requests:

```ruby
  ActiveSupport::Notifications.subscribe('cloudsearchable.execute_query') do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    # Your code here ...
  end
```

#### Instrumented events:

1. cloudsearchable.execute_query - Instruments search requests
2. cloudsearchable.post_record - Instruments record addition 
3. cloudsearchable.delete_record - Instruments record deletion
4. cloudsearchable.describe_domains - Instruments request for getting domains information

### Other Features

Cloudsearchable provides access the underlying AWS client objects, such as '''CloudSearch.client''' and '''class.cloudsearch_domains'''. For example here is how to drop domains associated with Customer class:

```ruby
  client = CloudSearch.client
  Customer.cloudsearch_domains.each do |key, domain|
    domain_name = domain.name
    puts "...dropping #{domain_name}"
    client.delete_domain(:domain_name => domain_name)
  end
```

See spec tests and source code for more information.

## Credits

* [Logan Bowers](https://github.com/loganb)
* [Peter Abrahamsen](https://github.com/rainhead)
* [Lane LaRue](https://github.com/luxx)
* [Philip White](https://github.com/philipmw)

Apache 2.0 License

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run the tests (`rake spec`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
