=begin
  daterange.rb - Range of Date
=end

require 'date'
require 'kagemai/util'

# Date::valid_date? has introduced from Ruby 1.8
unless Date.respond_to?(:valid_date?)
  class << Date
    alias_method :valid_date?, :exist?
  end
end

module Kagemai
  class DateRange
    DateStruct = Struct.new(:year, :month, :day)

    def initialize(start_date, end_date)
      @start_date = DateStruct.new(*ParseDate.parsedate(start_date, true)[0..2])
      @end_date = DateStruct.new(*ParseDate.parsedate(end_date, true)[0..2])
    end
    attr_reader :start_date, :end_date

    def each_month(&block)
      (@start_date.year..@end_date.year).each do |year|
        (1..12).each do |month|
          next if year == @start_date.year && month < @start_date.month
          next if year == @end_date.year && month > @end_date.month
          yield year, month
        end
      end
    end

    def each_day(&block)
      (@start_date.year..@end_date.year).each do |year|
        (1..12).each do |month|
          next if year == @start_date.year && month < @start_date.month
          next if year == @end_date.year && month > @end_date.month
          
          (1..31).each do |day|
            next if year == @start_date.year && month == @start_date.month && day < @start_date.day
            next if year == @end_date.year && month == @end_date.month && day > @end_date.day
            next unless Date.valid_date?(year, month, day)
            yield year, month, day
          end
          
        end
      end
    end

  end
end
