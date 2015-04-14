object @variant
attributes *variant_attributes

cache ['big_variant', root_object]

extends "spree/api/variants/small"

node :total_on_hand do
  root_object.total_on_hand
end


child(root_object.stock_items.accessible_by(current_ability) => :stock_items) do
  attributes :id, :count_on_hand, :stock_location_id, :backorderable
  attribute :available? => :available
  node(:stock_location_name) { |si| si.stock_location.name }
end
