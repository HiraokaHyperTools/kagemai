=begin
  dbiutil.rb: utils.
  
  Copyright(C) 2008 FUKUOKA Tomoyuki.
  
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
  
  $Id: dbiutil.rb 338 2008-02-16 16:22:08Z fukuoka $
=end

module Kagemai
  class ReportCollectionProxy
    def initialize(store, attr_id)
      @store = store
      @attr_id = attr_id
    end
    
    def fetch(choice_id, default)
      reports = @store.collect_reports_with_choice(@attr_id, choice_id)
      reports.size > 0 ? reports : default
    end
    
    def [](choice_id)
      fetch(choice_id, nil)
    end
  end
  
  class SQLType
    def initialize(name, opt = nil)
      @name = name
      @opt = opt
    end
    attr_reader :name, :opt
    
    def to_s()
      @name
    end
    
    def vt(size)
      name + "(#{size})" + (opt ? ' ' + opt : '')
    end
  end
  
  class ElementType
    def sql_type(sql_types)
      t = sql_types['varchar']
      r = "#{t.name}(#{max_size()})"
      t.opt ? r + ' ' + t.opt : r
    end
  end
  
  class TextElementType
    def sql_type(sql_types)
      sql_types['text'].name
    end
  end
end
