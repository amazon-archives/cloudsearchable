require 'aws-sdk'
require 'json'

module CloudSearch
  API_VERSION = "2011-02-01"

  def self.client
    @client ||= Aws::CloudSearch::Client.new
  end

  def self.client=(client)
    @client = client
  end

  #
  # Send an SDF document to CloudSearch via http post request.
  # Returns parsed JSON response, or raises an exception
  #
  def self.post_sdf endpoint, sdf
    self.post_sdf_list endpoint, [sdf]
  end

  def self.post_sdf_list endpoint, sdf_list
    uri = URI.parse("http://#{endpoint}/#{API_VERSION}/documents/batch")

    req = Net::HTTP::Post.new(uri.path)
    req.body = JSON.generate sdf_list
    req["Content-Type"] = "application/json"

    http = Net::HTTP.new uri.host,uri.port
    response = http.start{|http| http.request(req)}

    if response.is_a? Net::HTTPSuccess
      JSON.parse response.body
    else
      # Raise an exception based on the response see http://ruby-doc.org/stdlib-1.9.2/libdoc/net/http/rdoc/Net/HTTP.html
      response.error!
    end

  end
end
