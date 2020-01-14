=begin
  ReportType - レポートが持つ要素やその種別を表します。

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

require 'xmlscan/scanner'
require 'kagemai/elementtype'
require 'kagemai/logger'
require 'kagemai/sharedfile'

module Kagemai
  class ReportType
    include Enumerable

    def ReportType.load(filename)
      SharedFile.read_open(filename) do |file|
        XMLScanner.new(file).parse()
      end
    end
    
    def initialize(id = '', name = '')
      @id = id
      @name = name
      @elements = Array.new
      @use_cookie = false
      @description = ''

      @is_open_proc = nil
    end
    attr_reader :id, :name
    attr_accessor :description

    def use_cookie?() @use_cookie end

    def add_element_type(etype)
      @elements.push(etype)
      @use_cookie = @use_cookie || etype.use_cookie?
    end

    def set_element_types(etypes)
      @elements = etypes.clone
    end

    def delete_element_type(id)
      @elements.delete_if{|etype| etype.id == id && etype.can_delete?}
    end

    def each(&block)
      @elements.each(&block)
    end

    def [](id)
      @elements.find {|etype| etype.id == id}
    end

    def find_by_name(name)
      @elements.find {|etype| etype.name == name}
    end

    def use_cookie_elements()
      @elements.find_all{|etype| etype.use_cookie?}
    end

    def use_cookie_element_list()
      use_cookie_elements().map{|etype| etype.name}.join(', ')
    end

    def store(file, charset)
      file.puts %Q!<?xml version="1.0" encoding="#{charset}"?>!
      file.puts
      file.puts %Q!<ReportType id="#{@id}" name="#{@name.escape_h}">!
      file.puts '  <description>'
      file.puts '    ' + description
      file.puts '  </description>'
      file.puts
      
      @elements.each do |etype|
        indent = '  '
        file.puts indent + etype.to_xml(indent)
        file.puts ''
      end

      file.puts '</ReportType>'
    end

    def open?(message)
      is_open_proc.call(message)
    end

    def is_open_proc()
      unless @is_open_proc then
        cond = {}

        @elements.each do |etype|
          next unless etype.kind_of?(SelectElementType)
          next if etype['close_by'].to_s.empty?
          cond[etype.id] = etype['close_by'].split(/,/).collect{|s| s.strip}
        end

        @is_open_proc = Proc.new{|message|
          opened = false
          cond.each do |eid, s|
            opened ||= !s.include?(message[eid])
          end
          opened
        }
      end

      @is_open_proc
    end

    class XMLScanner < XMLScan::XMLScanner
      def initialize(port)
        super
        etype_classes = [
          StringElementType, 
          SelectElementType, 
          MultiSelectElementType, 
          TextElementType, 
          BooleanElementType, 
          FileElementType
        ]

        @element_types = {}
        etype_classes.each do |eclass|
          @element_types[eclass.tagname] = eclass
        end
      end

      def parse()
        Logger.debug('ReportType', "parse()")
        @rtype = nil
        @etypes = Array.new
        @descriptions = ['']
        super
        @rtype
      end

      def on_emptyelem(name, attr)
        Logger.debug('ReportType', "on_emptyelm: #{name}")
	on_stag(name, attr)
	on_etag(name)
      end

      def on_entityref(ref)
        Logger.debug('Message', "on_entityref: ref = #{ref}")
        on_chardata('&' + ref + ';')
      end
      
      def on_stag(name, attr)
        Logger.debug('ReportType', "on_stag: #{name}")
        
        attr_u = Hash.new
        attr.each {|key, value| 
          attr_u[key.dup.untaint] = value.dup.untaint # untaint key/value.
        } 
        attr = attr_u
        
        if @element_types[name] then
          @etypes.push(@element_types[name].new(attr))
        else
          case name
          when 'ReportType'
            @rtype = ReportType.new(attr['id'], attr['name'])
          when 'description'
            @rtype.description = ''
          when 'choice'
            @choice = SelectElementType::Choice.new(attr)
          end
        end
        @descriptions.push('')
      end

      def on_chardata(cdata)
        Logger.debug('ReportType', "on_chardata: #{cdata.inspect}")

        str = @descriptions.pop()
        Logger.debug('ReportType', "on_chardata: str = #{str.inspect}")

        striped = cdata.to_s.sub(/^\s+/, '')
        unless striped.empty?
          str += striped
        end

        @descriptions.push(str)
        Logger.debug('ReportType', "on_chardata: desc = #{str.inspect}")
      end

      def on_etag(name)
        Logger.debug('ReportType', "on_etag: #{name}")
        description = @descriptions.pop().unescape_h
        if @element_types[name]
          Logger.debug('ReportType', "on_etag: description = #{description.inspect}")
          etype = @etypes.pop
          etype.description = description.strip
          @rtype.add_element_type(etype)
        elsif name == 'choice' && @etypes.last.kind_of?(SelectElementType)
          @choice.description = description
          @etypes.last.add_choice(@choice)
        elsif name == 'description'
          @rtype.description = description
        end
      end
    end

  end
end
