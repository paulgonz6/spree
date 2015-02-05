module Spree
  module Behaviors
    class Base
      class BehaviorFailureError < StandardError; end
      attr_reader :errors, :object
      class_attribute :pre_run_list
      class_attribute :post_run_list
      self.pre_run_list = []
      self.post_run_list = []

      def initialize(object)
        @object = object
        @errors = {}
      end

      def execute!
        execute || raise(BehaviorFailureError.new(errors.inspect))
      end

      def execute
        execute_run_list(pre_run_list)
        run
        execute_run_list(post_run_list)
        errors.blank?
      end

      protected

        def run
          raise NotImplementedError
        end

      private

        def execute_run_list(run_list)
          run_list.each do |run_list_item|
            run_list_item.new(object).execute
            errors.deep_merge!(run_list_item.errors)
          end
        end
    end
  end
end
