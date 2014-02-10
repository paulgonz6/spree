# FORK_STATUS: PR was accepted by Spree. https://github.com/spree/spree/commit/e3c8b0f84a4cb6505d0b40c5d9ef541804860822
object @product
cache @product
attributes *product_attributes
node(:display_price) { |p| p.display_price.to_s }
node(:has_variants) { |p| p.has_variants? }
child :master => :master do
  extends "spree/api/variants/show"
end

child :variants => :variants do
  extends "spree/api/variants/show"
end

child :option_types => :option_types do
  attributes *option_type_attributes
end

child :product_properties => :product_properties do
  attributes *product_property_attributes
end
