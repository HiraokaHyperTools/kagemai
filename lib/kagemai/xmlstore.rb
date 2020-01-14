=begin
  XMLFileStore - Save reports in individual files
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

    def increment_view_count(report_id)
      transaction {
        report = load(@report_type, report_id)
        report.view_count += 1
        update(report)
      }
    end
    
  end
end
