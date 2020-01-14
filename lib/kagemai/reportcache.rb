=begin
  ReportCache

  Copyright(C) 2002-2008 FUKUOKA Tomoyuki.

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

  $Id: reportcache.rb 245 2008-02-05 15:56:07Z fukuoka $
=end

require 'pstore'

unless defined?(RubyPStore) then
  RubyPStore = PStore
end

module Kagemai
  class Message
    def _dump(limits)
      data = {}
      data['id'] = @id
      data['time'] = @time
      
      @type.each do |etype|
        data[etype.id] = @elements[etype.id].value
      end
      
      Marshal.dump(data)
    end

    def self._load(port)
      data = Marshal.load(port)

      type = Project.instance.report_type
      message = Message.new(type, data['id'])

      type.each do |etype|
        message[etype.id] = data.fetch(etype.id, etype.default)
      end
      message.time = data['time']
      message.modified = false

      message
    end
  end

  class Report
    def _dump(limits)
      data = []
      data << @id
      data << visible_size()
      
      data << @first
      if @first != @last then
        data << @last
      end
      
      Marshal.dump(data)
    end
    
    def self._load(port)
      data = Marshal.load(port)
      
      type = Project.instance.report_type
      report = Report.new(type, data.shift)
      size = data.shift

      report.add_message(data.shift)
      2.upto(size - 1) do |n|
        report.add_message(Message.new(type, n))
      end
      if size > 1 then
        report.add_message(data.shift)
      end
      
      report
    end
  end

  class ReportCache
    def initialize(filename)
      @filename = filename
      @db = nil
      @db = RubyPStore.new(@filename)
      @count_cache = "#{filename}.count"
      
      begin
        @db.transaction {
          # do nothing
        }
        FileUtils.chmod2(Config[:file_mode], @filename)
      rescue => e
        File.unlink(@filename)
        @db = nil # disable cache
      end
    end
    
    def store(report)
      return nil unless @db
      
      @db.transaction do
        update_collection(report) if @db.root?('collection')
        update_count(report) if @db.root?('count')
      end
    end
    
    def load_collection(report_type, attr_id = nil)
      return nil unless @db
      
      collection = nil
    
      begin
        @db.transaction do
          return nil unless @db.root?('collection')
          
          if attr_id then
            return nil unless @db['collection'].has_key?(attr_id)
            collection = @db['collection'][attr_id]
          else
            collection = @db['collection'].each_value{|c| return c}
          end
        end
      rescue
        File.unlink(@filename)
        @db = nil
        collection = nil
      end
      
      collection
    end

    def save_collection(attr_id, collection)
      return nil unless @db
      
      @db.transaction do
        @db['collection'] = {} unless @db.root?('collection')
        @db['collection'][attr_id] = collection
      end
    end

    def load_count(report_type, attr_id)
      return nil unless @db
      
      count = nil
      begin
        @db.transaction do
          count = @db.root?('count') ? @db['count'][attr_id] : nil
        end
      rescue
        File.unlink(@filename)
        @db = nil
        count = nil
      end

      count
    end

    def save_count(attr_id, count)
      return nil unless @db

      @db.transaction do
        @db['count'] = {} unless @db.root?('count')
        @db['count'][attr_id] = count
      end
    end

    def update_collection(report)
      return nil unless @db
      
      @db['collection'].each do |attr_id, collection|
        cur = report[attr_id]
        
        if report.size > 1 then
          pre = report.at(report.size - 1)[attr_id]
          pre.split(/,\n/).each do |attr|
            collection[attr].delete_if{|r| report.id.to_i == r.id.to_i}
          end
        end
        
        cur.split(/,\n/).each do |attr|
          reports = collection.has_key?(attr) ? collection[attr] : []
          reports << report
          collection[attr] = reports.sort{|a, b| a.id <=> b.id}
        end
      end
    end
    
    def update_count(report)
      return nil unless @db
      
      @db['count'].each do |attr_id, count|
        cur = report[attr_id]
        
        if report.size > 1 then
          pre = report.at(report.size - 1)[attr_id]
          next if pre == cur
          pre.split(/,\n/).each {|attr| count[attr] -= 1}
        end
        
        cur.split(/,\n/).each do |attr| 
          count[attr] = 0 unless count.has_key?(attr)
          count[attr] += 1
        end
      end
    end 

  end

end
