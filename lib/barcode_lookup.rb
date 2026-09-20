require 'net/http'
require 'cgi'
require 'json'

# Provide access to barcode lookup, validation and product search through the EAN-Search.org API
class BarcodeLookup

  class Version # :nodoc:
    MAJOR = 1
    MINOR = 0
    TINY  = 2

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
    return nil if no_result?(result)

    result[0]
  end

  # Lookup a single ISBN (ISBN-10)
  #
  # Arguments:
  # isbn: (String)
  def isbn_lookup(isbn)
    json = api_call("op=barcode-lookup&isbn=#{isbn}")
    result = JSON.parse(json)
    return nil if no_result?(result)

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
    product_list(JSON.parse(json))
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
    product_list(JSON.parse(json))
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
    product_list(JSON.parse(json))
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
    product_list(JSON.parse(json))
  end

  # Lookup the issuing country for a single barcode (GTIN, EAN, UPC or ISBN-13)
  # this works even if we don't have a product name for this barcode in our database
  #
  # Arguments:
  # barcode: (String)
  def issuing_country(ean)
    json = api_call("op=issuing-country&ean=#{ean}")
    result = JSON.parse(json)
    return nil if no_result?(result)

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
    return nil if no_result?(result)

    result[0]['barcode']
  end

  # Find the Amazon ASIN for a barcode (GTIN, EAN, UPC or ISBN-13)
  # returns nil if no ASIN was found
  #
  # Arguments:
  # barcode: (String)
  def find_asin_for_ean(ean)
    json = api_call("op=asin-for-ean-lookup&ean=#{ean}")
    result = JSON.parse(json)
    return nil if !result.is_a?(Array) || no_result?(result)

    result[0]['asin']
  end

  # Find the barcode (EAN) for an Amazon ASIN
  # returns nil if no barcode was found
  #
  # Arguments:
  # asin: (String)
  def find_ean_for_asin(asin)
    asin = CGI.escape(asin)
    json = api_call("op=ean-for-asin-lookup&asin=#{asin}")
    result = JSON.parse(json)
    return nil if !result.is_a?(Array) || no_result?(result)

    result[0]['ean']
  end

  # Find the Library of Congress Control Number (LCCN) for a barcode (GTIN, EAN, UPC or ISBN-13)
  # returns nil if no LCCN was found
  #
  # Arguments:
  # barcode: (String)
  def find_lccn_for_ean(ean)
    json = api_call("op=lccn-for-ean-lookup&ean=#{ean}")
    result = JSON.parse(json)
    return nil if !result.is_a?(Array) || no_result?(result)

    result[0]['lccn']
  end

  # Find the barcode (EAN) for a Library of Congress Control Number (LCCN)
  # there can be multiple barcodes for one LCCN, this returns the first one found
  # returns nil if no barcode was found
  #
  # Arguments:
  # lccn: (String)
  def find_ean_for_lccn(lccn)
    lccn = CGI.escape(lccn)
    json = api_call("op=ean-for-lccn-lookup&lccn=#{lccn}")
    result = JSON.parse(json)
    return nil if !result.is_a?(Array) || no_result?(result)

    result[0]['ean']
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

  # true if the API returned an empty list or an error message instead of a result
  def no_result?(result)
    result.is_a?(Array) && (result.empty? || result[0].key?('error'))
  end

  # the product list of a search result, raises the error message if the API returned one
  def product_list(result)
    return [] if result.is_a?(Array) && result.empty?
    raise result[0]['error'] if result.is_a?(Array) && result[0].key?('error')

    result['productlist']
  end

  def api_call(params, tries = 1)
    @uri = URI("#{@base_url}#{@token}&#{params}")
    response = Net::HTTP.start(@uri.host, @uri.port, use_ssl: true, read_timeout: @timeout) do |http|
      request = Net::HTTP::Get.new(@uri.request_uri, {'User-Agent' => 'ruby-eansearch/1.0'})
      http.request(request)
    end
    if response.code == '429' && tries < @max_api_tries
      sleep 1
      return api_call(params, tries + 1)
    end
    credits = response['X-Credits-Remaining'].to_s.strip
    @remain = credits.to_i if credits.match?(/\A\d+\z/)
    response.body
  end
end
