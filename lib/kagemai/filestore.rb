=begin
  FileStore - Save messages in individual files

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
=end

require 'fileutils'
require 'kagemai/config'
require 'kagemai/report'
require 'kagemai/message'
require 'kagemai/store'
require 'kagemai/util'
require 'kagemai/seqfile'
require 'kagemai/message_bundle'
require 'kagemai/pmutex'
require 'kagemai/xmlhelper'
require 'kagemai/reportcache'

module Kagemai
  class FileStore < Store
    SPOOL_NAME = 'spool'
    ID_FILENAME = 'id'
    LOCK_FILENAME = 'lock'
    ATTACHMENT_DIR_NAME = 'attachments'
    ATTACHMENT_SEQ_FILENAME = 'seq'

    def FileStore.obsolete?
      true
    end

    def FileStore.disp_name()
      'FileStore(obsolete)'
    end
    
    def FileStore.description()
      MessageBundle[:FileStore]
    end
    
    def FileStore.create(dir, project_id, report_type, charset)
      Dir.mkdir("#{dir}/#{SPOOL_NAME}")
      Dir.mkdir("#{dir}/#{SPOOL_NAME}/#{ATTACHMENT_DIR_NAME}")
      File.create("#{dir}/#{SPOOL_NAME}/#{ID_FILENAME}")
      File.create("#{dir}/#{SPOOL_NAME}/#{LOCK_FILENAME}")
      File.create("#{dir}/#{SPOOL_NAME}/#{ATTACHMENT_DIR_NAME}/#{ATTACHMENT_SEQ_FILENAME}")
      
      FileUtils.chmod2(Config[:dir_mode], "#{dir}/#{SPOOL_NAME}")
      FileUtils.chmod2(Config[:dir_mode], "#{dir}/#{SPOOL_NAME}/#{ATTACHMENT_DIR_NAME}")
      FileUtils.chmod2(Config[:file_mode], "#{dir}/#{SPOOL_NAME}/#{ID_FILENAME}")
      FileUtils.chmod2(Config[:file_mode], "#{dir}/#{SPOOL_NAME}/#{LOCK_FILENAME}")
      FileUtils.chmod2(Config[:file_mode], "#{dir}/#{SPOOL_NAME}/#{ATTACHMENT_DIR_NAME}/#{ATTACHMENT_SEQ_FILENAME}")
    end

    def FileStore.destroy(dir, id)
      %w(cache1 cache2).each do |name|
        File.unlink("#{dir}/#{name}")  if File.exist?("#{dir}/#{name}")
        File.unlink("#{dir}/#{name}~") if File.exist?("#{dir}/#{name}~")
      end
      Dir.delete_dir("#{dir}/#{SPOOL_NAME}")
    end
    
    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      @spool_path = "#{dir}/#{SPOOL_NAME}"
      @idfile_path = "#{@spool_path}/#{ID_FILENAME}"
      @attachment_path = "#{@spool_path}/#{ATTACHMENT_DIR_NAME}"
      @attachment_seq_path = "#{@attachment_path}/#{ATTACHMENT_SEQ_FILENAME}"
      
      @lockfilename = "#{@spool_path}/#{LOCK_FILENAME}"
      @lock = PMutex.new(@lockfilename)
      
      @message_reader = XMLMessageReader.new(charset)
      @message_writer = XMLMessageWriter.new(charset)
      
      @use_collection_cache = true
      @use_count_cache = true
      
      @collection_cache = nil
      @collection_cache_name = "#{@dir}/cache1"
      
      @count_cache = nil
      @count_cache_name = "#{@dir}/cache2"
    end

    def disable_cache()
      @collection_cache = nil
      @count_cache = nil
      @use_collection_cache = false
      @use_count_cache = false
    end
    
    def set_message_reader(reader)
      @message_reader = reader
    end

    def set_message_writer(writer)
      @message_writer = writer
    end

    def store(report)
      report_dir = "#{@spool_path}/#{report.id}"
      unless File.exist?(report_dir)
        Dir.mkdir(report_dir)
      end

      report.each do |message|
        next unless message.modified?
        File.open("#{report_dir}/#{message.id}", 'wb') do |file|
          @message_writer.write(file, message)
        end
        FileUtils.chmod2(Config[:file_mode], "#{report_dir}/#{message.id}")
      end

      collection_cache().store(report) if @use_collection_cache
      count_cache().store(report) if @use_count_cache
    end
    
    def store_with_id(report)
      begin
        nid = next_id()
      end while nid < report.id
      store(report)
    end
    
    def update(report)
      invalidate_cache()
      store(report)
    end
    
    def remake(report)
      invalidate_cache()
      store(report)
    end
    
    def load(report_type, id, raise_on_error = true)
      report_dir = "#{@spool_path}/#{id}"
      unless FileTest.directory?(report_dir) then
        if raise_on_error then
          raise ParameterError, MessageBundle[:err_invalid_report_id] % id.to_s
        else
          return nil
        end
      end

      report = Report.new(report_type, id)
      message_id = 1
      while true
        path = "#{report_dir}/#{message_id}"
        break unless FileTest.file?(path)
        File.open(path, 'rb') do |file|
          report.add_message(@message_reader.read(file, report_type, message_id))
        end
        message_id += 1
      end

      if report.size == 0 then
        raise RepositoryError, 
          "Reprot(id = #{id}) has no message. Repository may be broken." 
      end

      report
    end

    def size()
      @lock.synchronize {
        SeqFile.open(@idfile_path){ |idfile| idfile.current }
      }
    end

    def each(report_type, &block)
      @lock.synchronize {
        max = SeqFile.open(@idfile_path){ |idfile| idfile.current }
        (1..max).each do |report_id|
          report = load(report_type, report_id, false)
          block.call(report) if report
        end
      }
    end

    def search(report_type, cond_attr, cond_other, and_op, limit, offset, order)
      attr  = []
      other = []
      skip = []

      attr_match = Proc.new {|report|
        if cond_attr.match(report) then
          attr << report 
          skip[report.id.to_i] = true
        end
      }

      cond_match = Proc.new {|report|
        report.each do |message|
          if cond_other.match(message) then
            other << report
            skip[report.id.to_i] = true
            break
          end
        end
      }

      collection = nil
      if @use_collection_cache then
        collection = collection_cache().load_collection(report_type) 
      end

      if collection then
        collection.each_value do |reports|
          reports.each do |report|
            attr_match.call(report)
          end
        end
      end
      
      if collection.nil? || cond_other then
        @lock.synchronize {
          max = SeqFile.open(@idfile_path){ |idfile| idfile.current }
          (1..max).each do |report_id|
            next if !and_op && skip[report_id]
            begin
              report = load(report_type, report_id)
              attr_match.call(report) unless collection
              cond_match.call(report) if cond_other
            rescue ParameterError
              # ignore load error
            end
          end
        }
      end
      
      reports = and_op ? (attr & other) : (attr | other)
      reports.sort!{|a, b| a.id <=> b.id}
      Store::SearchResult.new(reports.size, limit, offset, reports[offset, limit])
    end

    def collect_reports(report_type, attr_id)
      collection = nil
      if @use_collection_cache then
        collection = collection_cache().load_collection(report_type, attr_id) 
      end
      return collection if collection
      
      collection = {}
      each(report_type) do |report|
        attrs = report[attr_id]
        attrs.split(/,\n/).each do |attr|
          if collection.has_key?(attr)
            collection[attr].push(report)
          else
            collection[attr] = [report]
          end
        end
      end
      
      if @use_collection_cache then
        collection_cache().save_collection(attr_id, collection)  
      end

      collection
    end

    def count_reports(report_type, attr_id)
      count = nil
      if @use_count_cache then
        count = count_cache().load_count(report_type, attr_id)  
      end
      return count if count

      count = Hash.new(0)
      each(report_type) do |report|
        attrs = report[attr_id]
        attrs.split(/,\n/).each {|attr| count[attr] += 1}
      end

      if @use_count_cache then
        count_cache().save_count(attr_id, count)  
      end

      count
    end

    def next_id()
      SeqFile.open(@idfile_path){ |idfile| idfile.next() }
    end

    def transaction(&block)
      @lock.synchronize(&block)
    end

    def store_attachment(attachment, fileinfo)
      seq = nil
      @lock.synchronize {
        seq = SeqFile.open(@attachment_seq_path){ |idfile| idfile.next() }
      }
      
      store_file = get_attachment_filename(seq)
  
      len = 4096
      File.open(store_file, 'wb') do |file|
        while (buff = attachment.read(len)) do
          file.write(buff)
        end
      end
      
      seq
    end

    def open_attachment(seq_id)
      File.open(get_attachment_filename(seq_id), 'rb')
    end

    def each_attachment()
      seq = nil
      @lock.synchronize {
        seq = SeqFile.open(@attachment_seq_path){ |idfile| idfile.current() }
      }
      
      1.upto(seq.to_i) do |i|
        file = open(get_attachment_filename(i), 'rb')
        begin
          yield file, i
        ensure
          file.close unless file.closed?
        end
      end
    end

    def add_element_type(report_type, etype)
      invalidate_cache()
    end

    def delete_element_type(report_type, etype_id)
      invalidate_cache()
    end

    def change_element_type(report_type)
      invalidate_cache()
    end

    private
    def get_attachment_filename(seq_id)
      "#{@attachment_path}/#{seq_id}"
    end

    def collection_cache()
      @collection_cache ||= ReportCache.new(@collection_cache_name)
    end

    def count_cache()
      @count_cache ||= ReportCache.new(@count_cache_name)
    end
    
    def invalidate_cache()
      if File.exist?(@collection_cache_name) then
        File.unlink(@collection_cache_name) 
      end
      
      if File.exist?(@count_cache_name) then
        File.unlink(@count_cache_name)
      end
    end
  end

end
