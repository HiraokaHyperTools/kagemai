=begin
  PStore - Report Store using PStore.

  Copyright(C) 2002-2004 FUKUOKA Tomoyuki.

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

  $Id: pstore.rb 409 2008-02-23 14:07:23Z fukuoka $
=end

require 'pstore'
require 'fileutils'
require 'kagemai/config'
require 'kagemai/report'
require 'kagemai/message'
require 'kagemai/store'
require 'kagemai/util'
require 'kagemai/seqfile'
require 'kagemai/message_bundle'
require 'kagemai/pmutex'

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

      @messages.each do |m|
        data << m
      end

      Marshal.dump(data)
    end

    def self._load(port)
      data = Marshal.load(port)

      type = Project.instance.report_type
      report = Report.new(type, data.shift)

      data.each do |m|
        report.add_message(m)
      end

      report
    end
  end

  class PStore < Store
    SPOOL_NAME = 'spool'
    ATTACHMENT_DIR_NAME = 'attachments'

    CACHE_FILENAME = 'cache'

    def self.description()
      MessageBundle[:PStore]
    end

    def self.create(dir, project_id, report_type, charset)
      Dir.mkdir("#{dir}/#{SPOOL_NAME}")
      Dir.mkdir("#{dir}/#{SPOOL_NAME}/#{ATTACHMENT_DIR_NAME}")

      FileUtils.chmod2(Config[:dir_mode], "#{dir}/#{SPOOL_NAME}")
      FileUtils.chmod2(Config[:dir_mode], "#{dir}/#{SPOOL_NAME}/#{ATTACHMENT_DIR_NAME}")
    end

    def self.destroy(dir, id)
      Dir.delete_dir("#{dir}/#{SPOOL_NAME}")
    end
    
    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      @spool_path = "#{dir}/#{SPOOL_NAME}"
      @attachment_path = "#{@spool_path}/#{ATTACHMENT_DIR_NAME}"

      @dbname = "#{@spool_path}/reports"
      @pstore = Kernel::PStore.new(@dbname)

      unless File.exists?(@dbname) then
        @pstore.transaction{ 
          @pstore['id'] = 0
          @pstore['seq'] = 0
        }
        FileUtils.chmod2(Config[:file_mode], @dbname)
      end

      @in_transaction = false
    end

    def store(report)
      @pstore[report.id] = report
    end

    def update(report)
      store(report)
    end
    
    def load(report_type, id)
      if @in_transaction then
        load2(report_type, id)
      else
        @pstore.transaction {
          load2(report_type, id)
        }
      end
    end

    def load2(report_type, id)
      raise RepositoryError, 
        "Reprot-#{id} has no message. Repository may be broken." unless @pstore.root?(id.to_i)
        
      @pstore[id.to_i]
    end

    def size()
      if @in_transaction then
        @pstore['id']
      else
        @pstore.transaction {
          @pstore['id']
        }
      end
    end

    def each(report_type)
      @pstore.transaction {
        max = @pstore['id']
        (1..max).each do |report_id|
          yield @pstore[report_id]
        end
      }
    end

    def search(report_type, cond_attr, cond_other, and_op = true)
      attr  = []
      other = []

      each(report_type) do |report|
        attr << report if cond_attr.match(report)
        next unless cond_other

        report.each do |message|
          if cond_other.match(message) then
            other << report
            break
          end
        end
      end

      and_op ? (attr & other) : (attr | other)
    end

    def collect_reports(report_type, attr_id)
      collection = {}
      
      each(report_type) do |report|
        attr = report[attr_id]
        if collection.has_key?(attr)
          collection[attr].push(report)
        else
          collection[attr] = [report]
        end
      end
      
      collection
    end

    def count_reports(report_type, attr_id)
      count = Hash.new(0)
      
      each(report_type) do |report|
        attr = report[attr_id]
        count[attr] += 1
      end

      count
    end

    def next_id()
      @pstore['id'] += 1
      @pstore['id']
    end

    def transaction()
      @pstore.transaction {
        @in_transaction = true
        begin
          yield
        ensure
          @in_transaction = false
        end
      }
    end

    def store_attachment(attachment, fileinfo)
      seq = nil
      @pstore.transaction {
        seq = @pstore['seq']
        @pstore['seq'] += 1
      }
      
      store_file = get_attachment_filename(seq)
  
      len = 4096
      File.open(store_file, 'wb') do |file|
        while (buff = attachment.read(len)) do
          file.write(buff)
        end
      end
      attachment.close

      seq
    end

    def open_attachment(seq_id)
      File.open(get_attachment_filename(seq_id), 'rb')
    end

    def each_attachment()
      seq = nil
      @pstore.transaction {
        seq = @pstore['seq']
      }
      
      1.upto(seq.to_i) do |i|
        File.open(get_attachment_filename(i), 'rb') do |file|
          yield file, i
        end
      end
    end

    def add_element_type(etype)
      # nothing to do.
    end

    def delete_element_type(etype_id)
      # nothing to do.
    end

    def change_element_type(report_type)
      # nothing to do.
    end

    private
    def get_attachment_filename(seq_id)
      "#{@attachment_path}/#{seq_id}"
    end
  end

end
