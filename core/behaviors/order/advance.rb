module Spree
  module Behaviors
    module Order
      class Advance < Base
        def run
          while object.next; end
        end
      end
    end
  end
end
