# frozen_string_literal: true

require "spec_helper"
require "active_support/testing/time_helpers"

describe Datagrid::Filters::DateFilter do
  it "supports date range argument" do
    e1 = Entry.create!(created_at: 7.days.ago)
    e2 = Entry.create!(created_at: 4.days.ago)
    e3 = Entry.create!(created_at: 3.days.ago)
    e4 = Entry.create!(created_at: 1.day.ago)

    report = test_report(created_at: 5.day.ago..3.days.ago) do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end

    expect(report.created_at).to eq(5.days.ago.to_date..3.days.ago.to_date)
    expect(report.assets).not_to include(e1)
    expect(report.assets).to include(e2)
    expect(report.assets).to include(e3)
    expect(report.assets).not_to include(e4)
  end

  it "raises when range assigned to non-range filter" do
    expect do
      test_report(created_at: 5.day.ago..3.days.ago) do
        scope { Entry }
        filter(:created_at, :date)
      end
    end.to raise_error(ArgumentError)
  end

  it "endless date range argument" do
    e1 = Entry.create!(created_at: 7.days.ago)
    e2 = Entry.create!(created_at: 4.days.ago)
    report = test_report(created_at: 5.days.ago..) do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.assets).not_to include(e1)
    expect(report.assets).to include(e2)
    report.created_at = ..5.days.ago
    expect(report.assets).to include(e1)
    expect(report.assets).not_to include(e2)
  end

  it "supports hash argument for range filter" do
    report = test_report do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end
    from = 5.days.ago
    to = 3.days.ago
    report.created_at = { from: from, to: to }
    expect(report.created_at).to eq(from.to_date..to.to_date)

    report.created_at = { "from" => from, "to" => to }
    expect(report.created_at).to eq(from.to_date..to.to_date)

    report.created_at = {}
    expect(report.created_at).to eq(nil)

    report.created_at = { from: nil, to: nil }
    expect(report.created_at).to eq(nil)

    report.created_at = { from: Date.today, to: nil }
    expect(report.created_at).to eq(Date.today..nil)

    report.created_at = { from: nil, to: Date.today }
    expect(report.created_at).to eq(nil..Date.today)

    report.created_at = { from: Time.now, to: Time.now }
    expect(report.created_at).to eq(Date.today..Date.today)
  end

  { active_record: Entry, mongoid: MongoidEntry, sequel: SequelEntry }.each do |orm, klass|
    describe "with orm #{orm}", orm => true do
      describe "date to timestamp conversion" do
        let(:klass) { klass }
        subject do
          test_report(created_at: _created_at) do
            scope { klass }
            filter(:created_at, :date, range: true)
          end.assets.to_a
        end

        def entry_dated(date)
          klass.create(created_at: date)
        end

        context "when single date paramter given" do
          let(:_created_at) { Date.today }
          it { should include(entry_dated(1.second.ago)) }
          it { should include(entry_dated(Date.today.end_of_day)) }
          it { should_not include(entry_dated(Date.today.beginning_of_day - 1.second)) }
          it { should_not include(entry_dated(Date.today.end_of_day + 1.second)) }
        end

        context "when range date range given" do
          let(:_created_at) { [Date.yesterday, Date.today] }
          it { should include(entry_dated(1.second.ago)) }
          it { should include(entry_dated(1.day.ago)) }
          it { should include(entry_dated(Date.today.end_of_day)) }
          it { should include(entry_dated(Date.yesterday.beginning_of_day)) }
          it { should_not include(entry_dated(Date.yesterday.beginning_of_day - 1.second)) }
          it { should_not include(entry_dated(Date.today.end_of_day + 1.second)) }
        end
      end
    end
  end

  it "should support date range given as array argument" do
    e1 = Entry.create!(created_at: 7.days.ago)
    e2 = Entry.create!(created_at: 4.days.ago)
    e3 = Entry.create!(created_at: 1.day.ago)
    report = test_report(created_at: [5.day.ago.to_date.to_s, 3.days.ago.to_date.to_s]) do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.assets).not_to include(e1)
    expect(report.assets).to include(e2)
    expect(report.assets).not_to include(e3)
  end

  it "should support minimum date argument" do
    e1 = Entry.create!(created_at: 7.days.ago)
    e2 = Entry.create!(created_at: 4.days.ago)
    e3 = Entry.create!(created_at: 1.day.ago)
    report = test_report(created_at: [5.day.ago.to_date.to_s, nil]) do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.assets).not_to include(e1)
    expect(report.assets).to include(e2)
    expect(report.assets).to include(e3)
  end

  it "should support maximum date argument" do
    e1 = Entry.create!(created_at: 7.days.ago)
    e2 = Entry.create!(created_at: 4.days.ago)
    e3 = Entry.create!(created_at: 1.day.ago)
    report = test_report(created_at: [nil, 3.days.ago.to_date.to_s]) do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.assets).to include(e1)
    expect(report.assets).to include(e2)
    expect(report.assets).not_to include(e3)
  end

  it "should find something in one day interval" do
    e1 = Entry.create!(created_at: 7.days.ago)
    e2 = Entry.create!(created_at: 4.days.ago)
    e3 = Entry.create!(created_at: 1.day.ago)
    report = test_report(created_at: (4.days.ago.to_date..4.days.ago.to_date)) do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.assets).not_to include(e1)
    expect(report.assets).to include(e2)
    expect(report.assets).not_to include(e3)
  end

  it "should invert invalid range" do
    range = 1.days.ago..7.days.ago
    e1 = Entry.create!(created_at: 7.days.ago)
    e2 = Entry.create!(created_at: 4.days.ago)
    e3 = Entry.create!(created_at: 1.day.ago)
    report = test_report(created_at: range) do
      scope { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.created_at).to eq(range.last.to_date..range.first.to_date)
    expect(report.assets).to include(e1)
    expect(report.assets).to include(e2)
    expect(report.assets).to include(e3)
  end

  it "should support block" do
    date = Date.new(2018, 0o1, 0o7)
    time = Time.utc(2018, 0o1, 0o7, 2, 2)
    report = test_report(created_at: date) do
      scope { Entry }
      filter(:created_at, :date, range: true) do |value|
        where(created_at: value)
      end
    end
    expect(report.assets).not_to include(Entry.create!(created_at: time - 1.day))
    expect(report.assets).to include(Entry.create!(created_at: time))
  end

  context "when date format is configured" do
    around(:each) do |example|
      with_date_format do
        example.run
      end
    end

    it "should have configurable date format" do
      report = test_report(created_at: "10/01/2013") do
        scope  { Entry }
        filter(:created_at, :date)
      end
      expect(report.created_at).to eq(Date.new(2013, 10, 0o1))
    end

    it "should support default explicit date" do
      report = test_report(created_at: Date.parse("2013-10-01")) do
        scope  { Entry }
        filter(:created_at, :date)
      end
      expect(report.created_at).to eq(Date.new(2013, 10, 0o1))
    end
  end

  it "should automatically reverse if first more than last" do
    report = test_report(created_at: %w[2013-01-01 2012-01-01]) do
      scope  { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.created_at).to eq(Date.new(2012, 0o1, 0o1)..Date.new(2013, 0o1, 0o1))
  end
  it "should automatically reverse if first more than last" do
    report = test_report(created_at: %w[2013-01-01 2012-01-01]) do
      scope  { Entry }
      filter(:created_at, :date, range: true)
    end
    expect(report.created_at).to eq(Date.new(2012, 0o1, 0o1)..Date.new(2013, 0o1, 0o1))
  end

  it "should nullify blank range" do
    report = test_report(created_at: [nil, nil]) do
      scope  { Entry }
      filter(:created_at, :date, range: true)
    end

    expect(report.created_at).to eq(nil)
  end

  it "should properly format date in filter_value_as_string" do
    with_date_format do
      report = test_report(created_at: "2012-01-02") do
        scope  { Entry }
        filter(:created_at, :date)
      end
      expect(report.filter_value_as_string(:created_at)).to eq("01/02/2012")
    end
  end

  it "deserializes range" do
    report = test_report do
      scope  { Entry }
      filter(:created_at, :date, range: true)
    end

    value = Date.new(2012, 1, 1)..Date.new(2012, 1, 2)
    report.created_at = value.as_json
    expect(report.created_at).to eq(value)
  end

  it "supports search by timestamp column" do
    report = test_report(created_at: Date.today) do
      scope { Entry }
      filter(:created_at, :date)
    end
    e1 = Entry.create!(created_at: Date.yesterday + 23.hours)
    e2 = Entry.create!(created_at: Date.today.to_time)
    e3 = Entry.create!(created_at: Date.today + 12.hours)
    e4 = Entry.create!(created_at: Date.today + 23.hours)
    e5 = Entry.create!(created_at: Date.tomorrow)
    expect(report.assets).to_not include(e1)
    expect(report.assets).to include(e2)
    expect(report.assets).to include(e3)
    expect(report.assets).to include(e4)
    expect(report.assets).to_not include(e5)
  end

  it "allows filter to be defined before scope" do
    class ParentGrid < Datagrid::Base
      filter(:created_at, :date, range: true)
    end

    class ChildGrid < ParentGrid
      scope do
        Entry
      end
    end

    expect(ChildGrid.new.assets).to eq([])
  end
end
