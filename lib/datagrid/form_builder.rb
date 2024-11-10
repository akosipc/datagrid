# frozen_string_literal: true

require "action_view"

module Datagrid
  module FormBuilder
    # @param filter_or_attribute [Datagrid::Filters::BaseFilter, String, Symbol] filter object or filter name
    # @param options [Hash] options of rails form input helper
    # @return [String] a form input html for the corresponding filter
    def datagrid_filter(filter_or_attribute, **options, &block)
      filter = datagrid_get_filter(filter_or_attribute)
      send(filter.form_builder_helper_name, filter, **options, &block)
    end

    # @param filter_or_attribute [Datagrid::Filters::BaseFilter, String, Symbol] filter object or filter name
    # @param text [String, nil] label text, defaults to <tt>filter.header</tt>
    # @param options [Hash] options of rails <tt>label</tt> helper
    # @return [String] a form label tag for the corresponding filter name
    def datagrid_label(filter_or_attribute, text = nil, **options, &block)
      filter = datagrid_get_filter(filter_or_attribute)
      options = { **filter.label_options, **options }
      label(filter.name, text || filter.header, **options, &block)
    end

    # @visibility private
    def datagrid_filter_input(attribute_or_filter, **options, &block)
      filter = datagrid_get_filter(attribute_or_filter)
      options = add_filter_options(filter, **options)
      type = options.delete(:type)&.to_sym
      if %i[datetime-local date].include?(type)
        if options.key?(:value) && options[:value].nil? &&
           # https://github.com/rails/rails/pull/53387
           (options[:value] = "")
        end
      elsif options[:value]
        options[:value] = filter.format(options[:value])
      end
      case type
      when :"datetime-local"
        datetime_local_field filter.name, **options, &block
      when :date
        date_field filter.name, **options, &block
      when :textarea
        text_area filter.name, value: object.filter_value_as_string(filter), **options, &block
      when :checkbox
        value = options.fetch(:value, 1).to_s
        if filter.enum_checkboxes? && enum_checkbox_checked?(filter, value)
          options = {checked: true, **options}
        end
        check_box filter.name, options, value
      when :hidden
        hidden_field filter.name, **options
      when :number
        number_field filter.name, **options
      when :select
        select(
          filter.name,
          object.select_options(filter) || [],
          {
            include_blank: filter.include_blank,
            prompt: filter.prompt,
            include_hidden: false,
          },
          multiple: filter.multiple?,
          **options,
          &block
        )
      else
        text_field filter.name, value: object.filter_value_as_string(filter), **options, &block
      end
    end

    protected

    def datagrid_extended_boolean_filter(filter, options = {}, &block)
      datagrid_filter_input(filter, **options, type: :select, &block)
    end

    def datagrid_boolean_filter(filter, options = {})
      datagrid_filter_input(filter.name, **options, type: :checkbox)
    end

    def datagrid_date_filter(filter, options = {})
      datagrid_range_filter(:date, filter, options)
    end

    def datagrid_date_time_filter(filter, options = {})
      datagrid_range_filter(:datetime, filter, options)
    end

    def datagrid_default_filter(filter, options = {})
      datagrid_filter_input(filter, **options)
    end

    def datagrid_enum_filter(filter, options = {}, &block)
      if filter.enum_checkboxes?
        elements = object.select_options(filter).map do |element|
          text, value = @template.send(:option_text_and_value, element)
          checked = enum_checkbox_checked?(filter, value)
          [value, text, checked]
        end
        render_partial(
          "enum_checkboxes",
          {
            elements: elements,
            form: self,
            filter: filter,
            options: options,
          },
        )
      else
        datagrid_filter_input(filter, **options, type: :select, &block)
      end
    end

    def enum_checkbox_checked?(filter, option_value)
      current_value = object.filter_value(filter)
      if current_value.respond_to?(:include?)
        # Typecast everything to string
        # to remove difference between String and Symbol
        current_value.map(&:to_s).include?(option_value.to_s)
      else
        current_value.to_s == option_value.to_s
      end
    end

    def datagrid_integer_filter(filter, options = {})
      options[:value] = "" if filter.multiple? && object[filter.name].blank?
      datagrid_range_filter(:integer, filter, options)
    end

    def datagrid_dynamic_filter(filter, options = {})
      field, operation, value = object.filter_value(filter)
      options = add_filter_options(filter, **options)
      field_input = dynamic_filter_select(
        filter.name,
        object.select_options(filter) || [],
        {
          include_blank: filter.include_blank,
          prompt: filter.prompt,
          include_hidden: false,
          selected: field,
        },
        **add_html_classes(options, "datagrid-dynamic-field"),
        name: @template.field_name(object_name, filter.name, "field"),
      )
      operation_input = dynamic_filter_select(
        filter.name, filter.operations_select,
        {
          include_blank: false,
          include_hidden: false,
          prompt: false,
          selected: operation,
        },
        **add_html_classes(options, "datagrid-dynamic-operation"),
        name: @template.field_name(object_name, filter.name, "operation"),
      )
      value_input = datagrid_filter_input(
        filter.name,
        **add_html_classes(options, "datagrid-dynamic-value"),
        value: value,
        name: @template.field_name(object_name, filter.name, "value"),
      )
      [field_input, operation_input, value_input].join("\n").html_safe
    end

    def dynamic_filter_select(name, variants, select_options, html_options)
      if variants.size <= 1
        value = variants.first
        # select options format may vary
        value = value.last if value.is_a?(Array)
        # don't render any visible input when there is nothing to choose from
        hidden_field(name, **html_options, value: value)
      else
        select(name, variants, select_options, html_options)
      end
    end

    def datagrid_range_filter(_type, filter, options = {})
      if filter.range?
        from_options = datagrid_range_filter_options(object, filter, :from, **options)
        to_options = datagrid_range_filter_options(object, filter, :to, **options)
        render_partial "range_filter", {
          from_options: from_options, to_options: to_options, filter: filter, form: self,
        }
      else
        datagrid_filter_input(filter, **options)
      end
    end

    def datagrid_range_filter_options(object, filter, type, **options)
      type_method_map = { from: :begin, to: :end }
      options[:value] = object[filter.name]&.public_send(type_method_map[type])
      options[:name] = @template.field_name(object_name, filter.name, type)
      # In case of datagrid ranged filter
      # from and to input will have same id
      if !options.key?(:id)
        # Rails provides it's own default id for all inputs
        # In order to prevent that we assign no id by default
        options[:id] = nil
      elsif options[:id].present?
        # If the id was given we prefix it
        # with from_ and to_ accordingly
        options[:id] = [type, options[:id]].join("_")
      end
      options
    end

    def datagrid_string_filter(filter, options = {})
      datagrid_range_filter(:string, filter, options)
    end

    def datagrid_float_filter(filter, options = {})
      datagrid_range_filter(:float, filter, options)
    end

    def datagrid_get_filter(attribute_or_filter)
      return attribute_or_filter unless Utils.string_like?(attribute_or_filter)

      object.class.filter_by_name(attribute_or_filter) ||
        raise(Error, "Datagrid filter #{attribute_or_filter} not found")
    end

    def add_html_classes(options, *classes)
      Datagrid::Utils.add_html_classes(options, *classes)
    end

    def partial_path(name)
      if (partials = options[:partials])
        partial_name = File.join(partials, name)
        # Second argument is []: no magical namespaces to lookup added from controller
        return partial_name if @template.lookup_context.template_exists?(partial_name, [], true)
      end
      File.join("datagrid", name)
    end

    def render_partial(name, locals)
      @template.render partial: partial_path(name), locals: locals
    end

    def add_filter_options(filter, **options)
      { **filter.default_input_options, **filter.input_options, **options }
    end

    class Error < StandardError
    end
  end
end
