=begin
  BaseDBIStore2 - abstract DBI report manager
=end

require 'dbi'
require 'kagemai/logger'
require 'kagemai/searchcond'
require 'kagemai/dbistore'

module Kagemai
  module BaseDBIStore2
    include BaseDBIStore
    
    def store_boolean(b)
      b
    end
    
    def load_boolean(d)
      d
    end
    
    def create_last_message_view(report_type)
      # do nothing
    end
    
    def drop_last_message_view()
      # do nothing
    end
    
    def build_report_cols(report)
      report_cols = []
      report_cols << "size = #{report.size}"
      unless report.hide? then
        report_cols << "create_time = '#{sql_time(report.first.time)}'"
        report_cols << "modify_time = '#{sql_time(report.last.time)}'"
      else
        report_cols << "create_time = '#{sql_time(report.at(1).time)}'"
        report_cols << "modify_time = '#{sql_time(report.at(report.size).time)}'"
      end
      report_cols
    end
    
    def build_message_col_holder(report)
      message_col_names = []
      message_cols = []
      report.type.each do |etype|
        message_col_names << col_name(etype.id)
        message_cols << '?'
      end
      message_col_names << MESSAGE_OPTION_COL_NAME
      message_cols << '?'
      message_col_names << 'hide'
      message_cols << '?'
      
      [message_col_names, message_cols]
    end
    
    def next_id()
      next_id = nil
      execute do |db|
        next_id = db.select_one("select max(id) from #{table_name('reports')}")[0].to_i + 1
        db.do("insert into #{table_name('reports')} (id, size) values (#{next_id}, 0)")
      end
      next_id
    end
    
    def store(report)
      message_col_names, message_cols = build_message_col_holder(report)
      
      message_sql = "insert into #{table_name('messages')} "
      message_sql += "(report_id, create_time, #{message_col_names.join(', ')}) "
      message_sql += "values "
      message_sql += "(#{report.id}, ?, #{message_cols.join(', ')})"
      
      execute do |db|
        db.prepare(message_sql) do |sth|
          report.each do |message|
            next unless message.modified?
            cols = [sql_time(message.time)]
            report.type.each{|etype| cols << message[etype.id]}
            cols << message.option_str()
            cols << store_boolean(message.hide?)
            sth.execute(*cols)
            message.modified = false
          end
        end

        update_report_index(db, report)
      end
    end

    def store_with_id(report)
      execute do |db|
        id, = db.select_one("select id from #{table_name('reports')} where id = #{report.id}")
        if id.nil? then
          db.do("insert into #{table_name('reports')} (id, size) values (#{report.id}, 0)")
        end
      end
      store(report)
    end
    
    def update_report_index(db, report)
      report_cols = build_report_cols(report)      
      
      # get first_message_id
      first_message_id = nil
      sql = "select min(id) from #{table_name('messages')} where report_id = #{report.id} and hide = false"
      first_message_id = db.select_one(sql)[0]
      
      # get last_message_id
      last_message_id = nil
      sql = "select max(id) from #{table_name('messages')} where report_id = #{report.id} and hide = false"
      last_message_id = db.select_one(sql)[0]
      if last_message_id.to_s.empty? then
        sql = "select max(id) from #{table_name('messages')} where report_id = #{report.id}"
        last_message_id = db.select_one(sql)[0]
        first_message_id = last_message_id
      end
      
      report_cols << "visible_size = #{report.visible_size}"
      report_cols << "first_message_id = #{first_message_id}"
      report_cols << "last_message_id = #{last_message_id}"
      sql = "update #{table_name('reports')} SET #{report_cols.join(', ')} where id = #{report.id}"
      db.do(sql)
    end
    
    def load(report_type, id)
      execute do |db|
        report = Report.new(report_type, id)
        message_id = 0
        
        db.select_all("select * from #{table_name('messages')} where report_id = #{id} order by id").each do |row|
          message = Message.new(report_type, message_id)
          
          report_type.each {|etype| message[etype.id] = row[col_name(etype.id)] }
          message.uid = row['id']
          message.time = row['create_time'].to_time()
          message.set_option_str(row[MESSAGE_OPTION_COL_NAME])
          message.hide = load_boolean(row['hide'])
          message.modified = false
          
          report.add_message(message)
          message_id += 1
        end
        
        if message_id == 0 then
          raise ParameterError, MessageBundle[:err_invalid_report_id] % id.to_s
        end
        
        report
      end
    end
    
    def increment_view_count(report_id)
      # ingore
    end
    
    def update(report)
      message_col_names, message_cols = build_message_col_holder(report)
      
      message_sql = "update #{table_name('messages')} set "
      message_sql += message_col_names.collect{|name| "#{name} = ?"}.join(", ")
      message_sql += " where id = ?"
      
      execute do |db|
        db.prepare(message_sql) do |sth|
          report.each do |message|
            next unless message.modified?
            values = []
            report.type.each{|etype| values << message[etype.id]}
            values << message.option_str()
            values << store_boolean(message.hide?)
            values << message.uid
            sth.execute(*values)
            message.modified = false
          end
        end
        
        update_report_index(db, report)
      end
    end
    
    def load_dummies(report_type, id)
      return [] if id.size == 0
      
      reports = {}
      execute do |db|
        cols = 'id, visible_size, first_message_id, last_message_id'
        
        sql = "select #{cols} from #{table_name('reports')} where id in (#{id.join(',')}) order by id"
        r_size = {}
        mid = []
        db.select_all(sql) do |tuple|
          rid = tuple['id'].to_i
          mid << tuple['first_message_id'].to_i 
          mid << tuple['last_message_id'].to_i 
          r_size[rid] = tuple['visible_size']
        end
        
        sql = "select * from #{table_name('messages')} where id in (#{mid.join(',')}) order by id"
        db.select_all(sql) do |tuple|
          message = Message.new(report_type)
          report_type.each do |etype|
            message[etype.id] = tuple[col_name(etype.id)]
          end
          message.time = tuple['create_time'].to_time
          message.modified = false
            
          rid = tuple['report_id'].to_i
          report = nil
          if reports.has_key?(rid) then
            report = reports[rid]
            2.upto(r_size[rid] - 1) do |n| # add dummy messages
              report.add_message(Message.new(report_type, n))
            end
          else
            report = Report.new(report_type, rid)
            reports[rid] = report
          end
          report.add_message(message)
        end
      end

      id.collect{|i| reports[i]}
    end
        
    def each_attachment()
      execute do |db|
        db.select_all("select id from #{table_name('attachments')}") do |row|
          seq = row['id'].to_i
          file = open_attachment(seq)
          begin
            yield file, seq
          ensure
            file.close
          end
        end
      end
    end
    
    def search(report_type, cond_attr, cond_other, and_op, limit, offset, order)
      id = nil
      attr_id = []
      if cond_attr && cond_attr.size > 0 then
        cond_attr_query = cond_attr.to_sql(SQL_SEARCH_OP) {|eid| col_name(eid)}
        where_clause = last_message_id_where_clause()
        
        query = "select report_id from #{table_name('messages')} where (#{cond_attr_query}) and (#{last_message_id_where_clause()}) order by #{order}"
        execute do |db|
          db.select_all(query) do |row|
            attr_id << row['report_id'].to_i
          end
        end
        id = attr_id
      end
      
      other_id = []
      if cond_other && cond_other.size > 0 then
        cond_other_query = cond_other.to_sql(SQL_SEARCH_OP)  {|eid| col_name(eid)}
        query = "select DISTINCT report_id from #{table_name('messages')} where #{cond_other_query} order by #{order}"
        
        execute do |db|
          db.select_all(query) do |row|
            other_id << row['report_id'].to_i
          end
        end
        
        if id.nil? then
          id = other_id
        else
          id = and_op ? (attr_id & other_id) : (attr_id | other_id)
        end
      end
      
      if id.nil? then
        # no condition, select all.
        id = []
        query = "select DISTINCT report_id from #{table_name('messages')} order by report_id"
        execute do |db|
          db.select_all(query) do |row|
            id << row['report_id'].to_i
          end
        end
      end
      
      reports = load_dummies(report_type, id[offset, limit])
      Store::SearchResult.new(id.size, limit, offset, reports)
    end        
    
    def collect_reports_with_choice(attr_id, choice_id)      
      reports = nil
      execute do |db|
        where_clause = last_message_id_where_clause()
        query =  "select report_id from #{table_name('messages')}"
        query += " where #{col_name(attr_id)} #{sql_op('regexp')} '#{choice_id}' and (#{where_clause}) order by id"
        rid_set = db.select_all(query)
        reports = rid_set.collect {|rid| load_dummy(@report_type, rid[0])}
      end
      reports
    end
    
    def count_reports(report_type, attr_id)
      counts = Hash.new(0)
      
      where_clause = last_message_id_where_clause()
      query = "select #{col_name(attr_id)} from #{table_name('messages')} where #{where_clause}"
      
      execute do |db|
        db.select_all(query).each do |tuple|
          attrs = tuple[col_name(attr_id)].to_s
          attrs.split(/,\n/).each {|attr| counts[attr] += 1}
        end
      end
      
      counts
    end
    
    def last_message_id_where_clause()
      query = "select last_message_id from #{table_name('reports')}"
      
      execute do |db|
        a = db.select_all(query)
        if a.empty?
          return sql_op(true)
        else
          return "#{table_name('messages')}.id in (#{a.flatten.join(',')})"
        end
      end
    end
    
  end
end
