=begin
  daterange.rb - Range of Date

  Copyright(C) 2002, 2003 FUKUOKA Tomoyuki.

  This file is part of KAGEMAI.  

  KAGEMAI is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  $Id: daterange.rb 246 2008-02-05 16:37:17Z fukuoka $
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
