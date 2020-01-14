=begin
  MRTGInfo - return open/close bug counts for MRTG
=end

require 'kagemai/cgi/action'
require 'kagemai/util'
require 'kagemai/message_bundle'

module Kagemai
  class MRTGInfo < Action
    def self.name()
      'mrtg'
    end
    Action::add_action(self)
    
    class MRTGInfoActionResult
      def initialize(name, type, open, close)
        @name = name
        @type = type
        @open = open
        @close = close
      end

      def respond(cgi, fluhs_log, show_env)
        total = @open + @close
        case @type
        when 1
          result = "#{total}\r\n#{@close}\r\n"
        when 2
          result = "#{@close}\r\n#{total}\r\n"
        else
          result = "#{@open}\r\n#{@close}\r\n"
        end
        print http_header(cgi, result.size)
        print result
      end

      def http_header(cgi, length)
        if defined?(MOD_RUBY) then
          Apache::request.headers_out.clear
        end

        opts = {
          'status' => 'OK',
          'type'   => 'text/plain',
          'length' => length
        }

	cgi.header(opts)
      end      
    end

    def execute()
      init_project()

      type = @cgi.get_param('t', '0').to_i
      
      open = 0
      close = 0
      @project.each do |report|
        if report.open? then
          open += 1
        else
          close += 1
        end
      end

      MRTGInfoActionResult.new(@project.name, type, open, close)
    end
  end
end
