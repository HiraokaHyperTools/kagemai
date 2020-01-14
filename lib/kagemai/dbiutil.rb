=begin
  dbiutil.rb: utils.
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
  
  class DateElementType
    def sql_type(sql_types)
      sql_types['date'].name
    end
  end
  
end
