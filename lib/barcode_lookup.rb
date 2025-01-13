require 'net/http'
require 'cgi'
require 'json'

# Provide access to barcode lookup, validation and product search through the EAN-Search.org API
class BarcodeLookup

  class Version # :nodoc:
    MAJOR = 1
    MINOR = 0
    TINY  = 1

    String = [MAJOR, MINOR, TINY].join('.')
  end

  # Initialize the class with an API access token from ean-search.org
  # See https://www.ean-search.org/ean-database-api.html
  #
  # Arguments:
  # api_token: (String)
  def initialize(api_token)
    @token = api_token
    @base_url = 'https://api.ean-search.org/api?format=json&token='
    @timeout = 180
    @max_api_tries = 3
    @remain = -1
  end

  # Lookup a single barcode (GTIN, EAN, UPC or ISBN-13)
  # you can optionally specify a preferred language for the product name
  #
  # Arguments:
  # barcode: (String)
  # language code: (Integer)
  def barcode_lookup(ean, preferred_lang = 1)
    json = api_call("op=barcode-lookup&ean=#{ean}&language=#{preferred_lang}")
    result = JSON.parse(json)
    return nil if result.is_a?(Array) && result[0].key?('error')

    result[0]
  end

  # Lookup a single ISBN (ISBN-10)
  #
  # Arguments:
  # isbn: (String)
  def isbn_lookup(isbn)
    json = api_call("op=barcode-lookup&isbn=#{isbn}")
    result = JSON.parse(json)
    return nil if result.is_a?(Array) && result[0].key?('error')

    result[0]
  end

  # Search for a product by name (exact match)
  #
  # Arguments:
  # name: (String)
  # language code: (Integer)
  # page: (Integer)
  def product_search(name, preferred_lang = 1, page = 0)
    name = CGI.escape(name)
    json = api_call("op=product-search&name=#{name}&language=#{preferred_lang}&page=#{page}")
    result = JSON.parse(json)
    raise result[0]['error'] if result.is_a?(Array) && result[0].key?('error')

    result['productlist']
  end

  # Search for a similar product by name
  #
  # Arguments:
  # name: (String)
  # language code: (Integer)
  # page: (Integer)
  def similar_product_search(name, preferred_lang = 1, page = 0)
    name = CGI.escape(name)
    json = api_call("op=similar-product-search&name=#{name}&language=#{preferred_lang}&page=#{page}")
    result = JSON.parse(json)
    raise result[0]['error'] if result.is_a?(Array) && result[0].key?('error')

    result['productlist']
  end

  # Search for a product by category and name (exact match)
  #
  # Arguments:
  # category code: (Integer)
  # name: (String)
  # language code: (Integer)
  # page: (Integer)
  def category_search(category, name, preferred_lang = 1, page = 0)
    name = CGI.escape(name)
    json = api_call("op=category-search&category=#{category}&name=#{name}&language=#{preferred_lang}&page=#{page}")
    result = JSON.parse(json)
    raise result[0]['error'] if result.is_a?(Array) && result[0].key?('error')

    result['productlist']
  end

  # Search for all products that start with this barcode prefix
  #
  # Arguments:
  # prefix: (String)
  # language code: (Integer)
  # page: (Integer)
  # only results in the preferred language: (Boolean)
  def barcode_prefix_search(prefix, preferred_lang = 1, page = 0, only_preferred_language = true)
    only_preferred_language = (only_preferred_language ? 1 : 0)
    json = api_call("op=barcode-prefix-search&prefix=#{prefix}&language=#{preferred_lang}&only-preferred-language=#{only_preferred_language}&page=#{page}")
    result = JSON.parse(json)
    raise result[0]['error'] if result.is_a?(Array) && result[0].key?('error')

    result['productlist']
  end

  # Lookup the issuing country for a single barcode (GTIN, EAN, UPC or ISBN-13)
  # this works even if we don't have a product name for this barcode in our database
  #
  # Arguments:
  # barcode: (String)
  def issuing_country(ean)
    json = api_call("op=issuing-country&ean=#{ean}")
    result = JSON.parse(json)
    return nil if result.is_a?(Array) && result[0].key?('error')

    result[0]['issuingCountry']
  end

  # Generate a PNG barcode image fort a code (GTIN, EAN, UPC or ISBN-13)
  #
  # Arguments:
  # barcode: (String)
  # width: (Integer)
  # height: (Integer)
  def barcode_image(ean, width = 102, height = 50)
    json = api_call("op=barcode-image&ean=#{ean}&width=#{width}&height=#{height}")
    result = JSON.parse(json)
    return nil if result.is_a?(Array) && result[0].key?('error')

    result[0]['barcode']
  end

  # Set the HTTP timeout for API calls in seconds
  #
  # Arguments:
  # second: (Integer)
  def timeout(sec)
    @timeout = sec
  end

  # Get the number of credits remaining for API calls
  # will return -1 before the first API call is made
  def credits_remaining
    @remain
  end

  protected

  def api_call(params, tries = 1)
    @uri = URI("#{@base_url}#{@token}&#{params}")
    response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: true, read_timeout: @timeout) do |http|
      request = Net::HTTP::Get.new(@uri.request_uri)
      http.request(request)
    end
    if response.code == '429' && tries < @max_api_tries
      sleep 1
      return api_call(params, tries + 1)
    end
    @remain = response['X-Credits-Remaining'] if response.key?('X-Credits-Remaining')
    response.body
  end
end
