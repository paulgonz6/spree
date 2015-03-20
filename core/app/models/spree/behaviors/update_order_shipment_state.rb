# Updates the +shipment_state+ attribute according to the following logic:
#
# shipped   when all Shipments are in the "shipped" state
# partial   when at least one Shipment has a state of "shipped" and there is another Shipment with a state other than "shipped"
#           or there are InventoryUnits associated with the order that have a state of "sold" but are not associated with a Shipment.
# ready     when all Shipments are in the "ready" state
# backorder when there is backordered inventory associated with an order
# pending   when all Shipments are in the "pending" state
#
# The +shipment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
module Spree
  module Behaviors
    class UpdateOrderShipmentState < OrderBase

      def run
        if order.backordered?
          order.shipment_state = 'backorder'
        else
          # get all the shipment states for this order
          shipment_states = shipments.states
          if shipment_states.size > 1
            # multiple shiment states means it's most likely partially shipped
            order.shipment_state = 'partial'
          else
            # will return nil if no shipments are found
            order.shipment_state = shipment_states.first
            # TODO inventory unit states?
            # if order.shipment_state && order.inventory_units.where(:shipment_id => nil).exists?
            #   shipments exist but there are unassigned inventory units
            #   order.shipment_state = 'partial'
            # end
          end
        end

        order.state_changed('shipment')
        order.shipment_state
      end
    end
  end
end
