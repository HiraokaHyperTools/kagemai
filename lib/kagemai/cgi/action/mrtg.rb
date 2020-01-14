=begin
  MRTGInfo - MRTG で open/close の推移グラフを作成するために、要求された時点での
             バグの open 数、close 数を１行で返します。

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
