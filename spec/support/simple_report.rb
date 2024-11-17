# frozen_string_literal: true

def test_grid(attributes = {}, &block)
  klass = test_grid_class(&block)
  klass.new(attributes)
end

def test_grid_class(&block)
  Class.new.tap do |klass|
    klass.class_eval do
      include Datagrid
      def self.name
        "TestGrid"
      end
    end
    klass.class_eval(&block) if block
  end
end

class SimpleReport
  include Datagrid

  scope do
    ::Entry.includes(:group).order("entries.created_at")
  end

  filter(:group_id, :integer, multiple: true)
  filter(:category, :enum, select: %w[first second])
  filter(:disabled, :xboolean)
  filter(:confirmed, :boolean)

  filter(:name) do |value|
    where(name: value)
  end

  column(:group, order: "groups.name") do
    group.name
  end

  column(:name, &:name)

  column(:actions, html: true) do |model|
    render partial: "/actions", locals: { model: model }
  end

  column(:pet, html: ->(data) { content_tag :em, data }) do
    pet&.upcase
  end

  column(:shipping_date, before: :group)

  column(:access_level, html: ->(data) { content_tag :h1, data }, after: :actions)

  def param_name
    :report
  end
end
