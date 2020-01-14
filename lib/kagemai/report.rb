=begin
  Report - a Bug Report

  Copyright(C) 200-2008 FUKUOKA Tomoyuki.

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
require 'kagemai/mail/mail'

module Kagemai
  class Report
    include Enumerable
    
    def initialize(type, id)
      @type = type
      @id = id.to_i
      @messages = Array.new
      @error = nil
      @first = nil
      @last = nil
    end
    attr_accessor :id, :error
    attr_reader :type
    
    def ==(rhs)
      @id == rhs.id
    end

    def eql?(rhs)
      @id == rhs.id
    end
    
    def hide?() 
      size() != visible_size()
    end
    
    def hash()
      @id.hash
    end
    
    def add_message(message)
      @messages.push(message)
      message.id = @messages.size
      message.report = self
      unless message.hide? then
        @first = message unless @first
        @last  = message
      end
      self
    end
    
    def each(&block)
      @messages.each(&block)
    end
    
    def each_attr()
      @type.each do |etype|
        next unless etype.report_attr?
        yield etype
      end
    end
    
    def size()
      @messages.size()
    end
    
    def visible_size()
      @messages.find_all{|m| !m.hide?}.size
    end
    
    def ensure()
      if size() > 0 && visible_size() == 0 then
        @first = @last = @messages[0]
      end
    end
        
    def first()
      @first
    end
    
    def last()
      @last
    end
    
    def at(id)
      id = id.to_i if id.kind_of?(String)
      @messages[id - 1]
    end
    
    def attr(name)
      @last.element(name).value
    end
    alias [] attr
    
    def element(name)
      @last.element(name)
    end
    
    def author()
      @first.name()
    end
    
    def create_time()
      @first.create_time
    end

    def modify_time()
      @last.create_time
    end

    def open?()
      @type.open?(@last)
    end
    
    def email_addresses(collect = true)
      addresses = {}
      
      @messages.each do |message|
        addr = message['email']
        email_notification = message.get_option('email_notification', false)
        addresses[addr] = email_notification && RMail::Address.validate(addr)
      end
    
      if collect then
        addresses.collect{|addr, notify| notify ? addr : nil}.compact
      else
        addresses
      end
    end

  end

end
