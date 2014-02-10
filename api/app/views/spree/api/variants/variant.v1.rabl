# FORK_STATUS: PR accepted by Spree: https://github.com/spree/spree/commit/e3c8b0f84a4cb6505d0b40c5d9ef541804860822 and https://github.com/spree/spree/commit/169274f2275dc8273e8beab79b874682afee9fac
attributes *variant_attributes
node(:display_price) { |p| p.display_price.to_s }
node(:options_text) { |v| v.options_text }
node(:in_stock) { |v| v.in_stock? }
child :option_values => :option_values do
  attributes *option_value_attributes
end
