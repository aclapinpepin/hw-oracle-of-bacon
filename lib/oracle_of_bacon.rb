require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  API_KEY = '38b99ce9ec87'

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri

  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    errors.add(:from, "can't use same name twice") if from == to
  end

  def initialize(api_key=API_KEY)
    @api_key = api_key
    @from = 'Kevin Bacon'
    @to = 'Kevin Bacon'
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e

      raise OracleOfBacon::NetworkError.new("there was a connection problem")
    end
    # your code here: create the OracleOfBacon::Response object
    @response = Response.new(xml)
  end

  def make_uri_from_arguments
    escaped_values = [api_key, from, to].map { |v| CGI.escape(v) }
    @uri = "http://oracleofbacon.org/cgi-bin/xml?p=#{escaped_values[0]}&a=#{escaped_values[1]}&b=#{escaped_values[2]}"
  end

  class Response
    attr_reader :type, :data
    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif ! @doc.xpath('/link').empty?
        parse_graph_response
      elsif ! @doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      else
        @data = 'unknown response'
        @type = :unknown
      end
    end

    def parse_graph_response
      actors = @doc.xpath('//actor').collect { |a| a.text }
      movies = @doc.xpath('//movie').collect { |m| m.text }
      @data = actors.zip(movies).flatten.compact
      @type = :graph
    end

    def parse_spellcheck_response
      @data = @doc.xpath('//match').collect { |n| n.text }
      @type = :spellcheck
    end

    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end
  end
end

