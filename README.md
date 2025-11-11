# BarcodeLookup

A Ruby Gem for GTIN, UPC, EAN and ISBN barcode lookup and validation using the API on https://www.ean-search.org

## Example

```ruby
#!/usr/bin/env ruby
require 'BarcodeLookup'


token = ENV["EAN_SEARCH_API_TOKEN"]
ean = '5099750442227'
isbn = '1119578884'

lookup = BarcodeLookup.new(token)

puts "Lookup single GTIN/UPC/EAN #{ean}:"
product = lookup.barcode_lookup(ean)
if product.nil?
    puts "EAN #{ean} not found"
else
    puts "EAN #{product['ean']} is #{product['name']} Google category #{product['googleCategoryId']}"
end

puts "Lookup single ISBN #{isbn}:"
book = lookup.isbn_lookup(isbn)
if book.nil?
    puts "EAN #{isbn} not found"
else
    puts "ISBN #{isbn} is #{book['name']}"
end

puts "Search for product name"
products = lookup.product_search("Michael Jackson Thriller")
for product in products
    puts "EAN #{product['ean']} is #{product['name']}"
end

puts "Search for similar product name"
products = lookup.similar_product_search("Michael Jackson Thriller but something else")
for product in products
    puts "EAN #{product['ean']} is #{product['name']}"
end

puts "Category search (category 15 is books)"
products = lookup.category_search(15, "Thriller")
for product in products
    puts "EAN #{product['ean']} is #{product['name']}"
end

puts "Barcode prefix search 4312*"
products = lookup.barcode_prefix_search('4312', 3, 0, 1)
for product in products
    puts "EAN #{product['ean']} is #{product['name']}"
end

puts "Lookup issuing country for EAN #{ean}:"
country = lookup.issuing_country(ean)
if country.nil?
    puts "Issuing country for EAN #{ean} unknown"
else
    puts "Issuing country for EAN #{product['ean']} is #{country}"
end

puts "Get a PNG barcode image for EAN #{ean}:"
png = lookup.barcode_image(ean, 300, 200)
if png.nil?
    puts "Error generating barcode image for EAN #{ean}"
else
    puts "Barcode image for EAN #{ean}: data:image/png;base64,#{png}"
end

puts "Credits remaining: " + lookup.credits_remaining.to_s

