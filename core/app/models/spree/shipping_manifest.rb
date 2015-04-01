module Spree::ShippingManifest
  ManifestItem = Struct.new(:line_item, :variant, :quantity, :states)

  def manifest(inventory_unit_scope: nil)
    # Grouping by the ID means that we don't have to call out to the association accessor
    # This makes the grouping by faster because it results in less SQL cache hits.
    inventory_units.merge(inventory_unit_scope).group_by(&:variant_id).map do |variant_id, units|
      units.group_by(&:line_item_id).map do |line_item_id, units|

        states = {}
        units.group_by(&:state).each { |state, iu| states[state] = iu.count }

        line_item = units.first.line_item
        variant = units.first.variant
        ManifestItem.new(line_item, variant, units.length, states)
      end
    end.flatten
  end
end
