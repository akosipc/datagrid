# frozen_string_literal: true

module Datagrid
  module Filters
    # @!visibility private
    module CompositeFilters
      def self.included(base)
        base.extend ClassMethods
      end

      # @!visibility private
      module ClassMethods
        def date_range_filters(field, from_options = {}, to_options = {})
          Utils.warn_once("date_range_filters is deprecated in favor of range option for date filter")
          from_options = normalize_composite_filter_options(from_options, field)
          to_options = normalize_composite_filter_options(to_options, field)

          filter(from_options[:name] || :"from_#{field.to_s.tr('.', '_')}", :date,
                 **from_options) do |date, scope, grid|
            grid.driver.greater_equal(scope, field, date)
          end
          filter(to_options[:name] || :"to_#{field.to_s.tr('.', '_')}", :date, **to_options) do |date, scope, grid|
            grid.driver.less_equal(scope, field, date)
          end
        end

        def integer_range_filters(field, from_options = {}, to_options = {})
          Utils.warn_once("integer_range_filters is deprecated in favor of range option for integer filter")
          from_options = normalize_composite_filter_options(from_options, field)
          to_options = normalize_composite_filter_options(to_options, field)
          filter(from_options[:name] || :"from_#{field.to_s.tr('.', '_')}", :integer,
                 **from_options) do |value, scope, grid|
            grid.driver.greater_equal(scope, field, value)
          end
          filter(to_options[:name] || :"to_#{field.to_s.tr('.', '_')}", :integer, **to_options) do |value, scope, grid|
            grid.driver.less_equal(scope, field, value)
          end
        end

        def normalize_composite_filter_options(options, _field)
          options = { name: options } if options.is_a?(String) || options.is_a?(Symbol)
          options
        end
      end
    end
  end
end
