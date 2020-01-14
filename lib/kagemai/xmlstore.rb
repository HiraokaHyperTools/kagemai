=begin
  XMLFileStore - １レポートを１つの XML ファイルに保存する Store です。

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

  $Id: xmlstore.rb 380 2008-02-20 14:35:59Z fukuoka $
=end

require 'kagemai/filestore'
require 'kagemai/report'
require 'kagemai/message'
require 'kagemai/sharedfile'

module Kagemai
  class XMLFileStore < FileStore

    def XMLFileStore.obsolete?
      false
    end

    def XMLFileStore.disp_name()
      'XMLFileStore'
    end

    def XMLFileStore.description()
      MessageBundle[:XMLFileStore]
    end

    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      message_reader = XMLMessageReader.new(charset)
      message_writer = XMLMessageWriter.new(charset, false, '  ')
      @report_reader = XMLReportReader.new(charset, message_reader)
      @report_writer = XMLReportWriter.new(charset, message_writer)
    end

    def store(report)
      filename = "#{@spool_path}/#{report.id}.xml"

      SharedFile.write_open(filename, false) do |file|
        @report_writer.write(file, report)
      end
      FileUtils.chmod2(Config[:file_mode], filename)

      collection_cache().store(report) if @use_collection_cache
      count_cache().store(report) if @use_count_cache
    end

    def load(report_type, id, raise_on_error = true)
      filename = "#{@spool_path}/#{id}.xml"
      unless FileTest.exist?(filename) then
        if raise_on_error then
          raise ParameterError, MessageBundle[:err_invalid_report_id] % id.to_s
        else
          return nil
        end
      end

      File.open(filename, 'rb') do |file|
        @report_reader.read(file, report_type, id)
      end
    end

  end
end
