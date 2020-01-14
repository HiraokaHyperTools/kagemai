=begin
  xmlhelper.rb - XML writer/readers to store reports or messages.
=end

require 'xmlscan/scanner'
require 'kagemai/message'
require 'kagemai/error'

module Kagemai

  class XMLReportWriter
    def initialize(charset, message_writer)
      @charset = charset
      @message_writer = message_writer
    end

    def write(port, report)
      port.puts("<?xml version=\"1.0\" encoding=\"#{@charset}\"?>")
      port.puts("")
      port.puts(%Q!<report id="#{report.id}" view_count="#{report.view_count}">!)

      report.each do |message|
        @message_writer.write(port, message)
      end

      port.puts("")
      port.puts("</report>")
    end
  end

  class XMLReportReader
    class XMLReportScanner < XMLScan::XMLScanner
      def initialize(port, type, id)
        super(port)
        @report_type = type
        @report_id = id
        @report = nil
        @cdata = ''
      end

      def on_stag(name, attr)
        case name
        when 'report'
          @report = Report.new(@report_type, @report_id)
          @report.view_count = attr['view_count'].to_i if attr['view_count']
        end
      end

      def parse()
        super()
        @report
      end
    end

    def initialize(charset, message_reader)
      @charset = charset
      @message_reader = message_reader
    end
    
    def read(port, report_type, id)
      input = port.read

      messages = []
      input = input.gsub(/<message .*?<\/message>/m) {|matched|
        messages << matched
        ''
      }
      if messages.size == 0
        raise RepositoryError, 
          "Report has no messages. \n input = #{input}"
      end

      report = XMLReportScanner.new(input, report_type, id).parse()
      unless report
        raise RepositoryError, "Report file may be broken: '#{port.path}'"
      end

      messages.each do |message|
        message = @message_reader.read(message, report_type, 0)
        report.add_message(message)
      end

      if report.size == 0
        raise RepositoryError, 
          "Report has no messages. Report file may be broken: '#{port.path}'"
      end

      report
    end

  end

  class XMLMessageWriter
    def initialize(charset, single_file = true, indent = '')
      @charset = charset
      @single_file = single_file
      @indent = indent
    end
    
    def write(file, message)
      file.puts("<?xml version=\"1.0\" encoding=\"#{@charset}\"?>") if @single_file
      file.puts("")
      
      attr = [
              ['id',   message.id],
              ['date', message.create_time],
              ['hide', message.hide?],
              ['ip_addr', message.ip_addr],
             ]
      attr_str = attr.collect{|k, v| %Q!#{k}="#{v}"!}.join(' ')
      
      puts(file, "<message #{attr_str}>") 
      message.type.each do |etype|
        element = message.element(etype.id)
        print(file, "  <element id=\"#{element.id}\">")
        if element.value then
          value = element.value.escape_h.gsub(/\r/m, '&#x000d;').gsub(/\n/m, '&#x000a;');
          file.print(value)
        end
        file.puts("</element>")
      end
      
      message.each_option do |id, value|
        puts(file, %Q!  <option id="#{id}" value="#{value.to_s}" />!)
      end

      puts(file, "</message>")
      message.modified = false
    end

    def print(file, str)
      file.print(@indent + str)
    end

    def puts(file, str)
      file.puts(@indent + str)
    end
  end

  class XMLMessageReader
    class XMLMessageScanner < XMLScan::XMLScanner
      def initialize(file, type, message_id)
        super(file)
        @message_id = message_id
        @type = type
        @message = nil
        @cdata = ''
      end

      def on_emptyelem(name, attr)
        case name
        when 'option'
          value = attr['value']
          value = true if value == 'true'
          value = false if value == 'false'
          @message.set_option(attr['id'], value)
        end
      end

      def on_stag(name, attr)
        case name
        when 'message'
          if @message_id == 0 && attr.has_key?('id') then
            @message_id = attr['id']
          end
          @message = Message.new(@type, @message_id)
          @message.time = Time.parsedate(attr['date'])
          @message.hide = true if attr['hide'] == 'true'
          @message.ip_addr = attr['ip_addr'] || ""
        when 'element'
          @cdata = ''
          @element_id = attr['id']
        end
      end

      def on_charref(code)
        # Logger.debug('Message', "on_charref: code = #{code}")
        on_chardata(code.chr)
      end

      def on_entityref(ref)
        # Logger.debug('Message', "on_entityref: ref = #{ref}")
        on_chardata('&' + ref + ';')
      end

      def on_chardata(cdata)
        # Logger.debug('Message', "on_chardata: cdata = #{cdata}")
        @cdata += cdata
      end

      def on_etag(name)
        if name == 'element' then
          # Logger.debug('Message', "on_etag: cdata = #{@cdata}")
          if @message.has_element?(@element_id) then
            @message[@element_id] = @cdata.unescape_h
          end
        end
      end

      def parse()
        super()
        @message
      end
    end

    def initialize(charset)
      @charset = charset
    end
    
    def read(file, report_type, id)
      begin
        filename = file.kind_of?(File) ? file.path : id.to_s
        message = XMLMessageScanner.new(file, report_type, id).parse()
        message.modified = false
        unless message
          raise RepositoryError, "Message file may be borken: '#{filename}'"
        end
        message
      rescue => e
        raise RepositoryError, "#{e}: '#{filename}' may be borken?"
      end
    end
  end

end
