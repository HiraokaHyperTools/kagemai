=begin
  Element - メッセージを構成する１つの要素を表します

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

  $Id: element.rb 10 2004-07-06 11:44:32Z fukuoka $
=end

module Kagemai
  class Element
    def initialize(type, message, value = nil)
      @message = message
      @type = type
      @value = value ? value : type.default
      
      @type.element_created(self)
    end
    attr_reader :type, :message
    attr_accessor :value
    
    def id()
      @type.id
    end
    
    def method_missing(name, *args)
      @type.send(name, self, *args)
    end
  end
end
