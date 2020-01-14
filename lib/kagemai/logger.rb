=begin
  Logger - デバッグ用のログを記録します

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

  $Id: logger.rb 450 2008-02-28 17:20:01Z fukuoka $
=end

require 'singleton'

module Kagemai
  class Logger
    include Singleton

    level = Struct.new('Level', :value, :name)
    DEBUG = level.new(0, 'DEBUG')
    WARN  = level.new(1, 'WARN ')
    ERROR = level.new(2, 'ERROR')
    FATAL = level.new(3, 'FATAL')

    def initialize()
      @level = ERROR
      @categories = Array.new
      @buffer = ''
    end
    attr_accessor :level
    attr_reader :buffer

    def add_category(category)
      @categories << category
    end

    def log(level, category, str)
      if @level.value <= level.value && @categories.include?(category) then
        @buffer += Logger.format(level, category, str)
      end
    end

    def clear()
      @buffer = ''
      @categories = Array.new
    end

    def self.format(level, category, str)
      level.name + ' ' + category + ': ' + str + "\r\n"
    end

    def self.log(level, category, str)
      instance().log(level, category, str)
    end

    def self.debug(category, str)
      log(DEBUG, category, str)
    end

    def self.warn(category, str)
      log(WARN, category, str)
    end

    def self.error(category, str)
      log(ERROR, category, str)
    end

    def self.fatal(category, str)
      log(fatal, category, str)
    end
    
    def self.level=(level)
      instance().level = level
    end

    def self.add_category(category)
      instance().add_category(category)
    end

    def self.buffer()
      instance().buffer
    end

    def self.clear()
      instance().clear()
    end

 end
end
