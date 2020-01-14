=begin
  Message -- １つのメッセージを表します

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

require 'kagemai/element'
require 'kagemai/logger'

module Kagemai
  class Message
    def initialize(type, id = 0)
      @uid = nil    # for RDB
      @report = nil
      @type = type
      @id = id
      @elements = Hash.new
      type.each do |etype|
        add_element(Element.new(etype, self))
      end
      @time = Time.now
      @modified = true
      @hide = false
      @ip_addr = ""
            
      @option = {}
    end
    attr_reader :type
    attr_writer :modified
    attr_accessor :id, :report, :time, :uid
    attr_accessor :ip_addr
    
    def name()
      if @elements.has_key?('name') then
        @elements['name']
      elsif @elements.has_key?('email') then
        @elements['email']
      else
        'Message#name: unknown'
      end
    end
    
    def name=(name)
      if @elements.has_key?('name') then
        @elements['name'].value = name
      elsif @elements.has_key?('email') then
        @elements['email'].value = name
      end
    end
    
    def body()
      element('body')
    end

    def create_time()
      @time.format()
    end
    
    def modified?() @modified end
    
    def hide?() @hide end
    
    def hide=(h) 
      @hide = h 
      @modified = true
    end
    
    def element(id)
      if @elements.has_key?(id)
        @elements[id]
      else
        raise NoSuchElementError, "element '#{id}' is not defined."
      end
    end

    def has_element?(id)
      @elements.has_key?(id)
    end

    def []=(id, value)
      element(id).value = value
      @modified = true
    end
    
    def [](id)
      element(id).value
    end

    def each()
      @type.each do |etype|
        yield(etype, etype.id, etype.name, @elements[etype.id].value)
      end
    end

    def set_option(name, value)
      @option[name] = value
      @modified = true
    end

    def get_option(name, default = nil)
      @option.has_key?(name) ? @option[name] : default
    end

    def each_option(&block)
      @option.sort.each(&block)
    end

    def option_str()
      @option.sort.collect{|name, value| "#{name}=#{value}"}.join(',')
    end

    def set_option_str(str)
      str.split(/,/).each do |option|
        name, value = option.split(/=/)
        value = true  if value == 'true'
        value = false if value == 'false'
        set_option(name, value)
      end
    end

    def open?()
      @type.open?(self)
    end
    
    def is_spam?(filter)
      strings = []
      @elements.values.each do |e|
        if e.type.kind_of?(StringElementType) || e.type.kind_of?(TextElementType) then
          strings << e.value
        end
      end
      filter.call(strings)
    end
    
    ################################################################
    private

    def add_element(element)
      @elements[element.id] = element
      @modified = true
    end

  end

end
