=begin
  BaseDBIStore3 - abstract DBI report manager
  
  Copyright(C) 2002-2008 FUKUOKA Tomoyuki.
  
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

require 'dbi'
require 'tempfile'
require 'kagemai/logger'
require 'kagemai/searchcond'
require 'kagemai/dbiutil'

module Kagemai  
  module BaseDBIStore3
    
    def self.create_driver_url(driver_name, dbname, args)
      db_args = args ? args.dup : {}
      db_args['database'] = dbname
      db_args_str = db_args.collect{|k, v| "#{k}=#{v}"}.join(';')

      "DBI:#{driver_name}:#{db_args_str}"
    end
    
    def self.create(type, dir, project_id, report_type, charset)
      begin
        init_tables(type, dir, project_id, report_type, charset)
      rescue Exception => e
        destroy(type, dir, project_id)
        raise e
      end
    end
    
    def self.destroy(type, dir, project_id)
      tables = %w(reports messages attachments)
      store  = type.new(dir, project_id, nil, nil)
      store.transaction do
        store.execute do |db|
          tables.each {|table| db.do("drop table #{store.table_name(table)}")}
        end
      end
    end
    
    def base_report_cols()
      [
       'id int primary key',
       'size int',
       'visible_size int',
       "author      #{sql_types['varchar'].vt(255)}",
       "create_time #{sql_types['timestamp']}",
       "modify_time #{sql_types['timestamp']}",
      ]
    end
    
    def base_message_cols()
      [
       "id          #{sql_types['serial']} primary key",
       "report_id   int",
       "create_time #{sql_types['timestamp']}",
       "hide        #{sql_types['boolean']}",
       "ip_addr     #{sql_types['varchar'].vt(15)}",
       "k_options   #{sql_types['varchar'].vt(255)}",
      ]
    end
    
    def self.init_tables(type, dir, project_id, report_type, charset)
      store = type.new(dir, project_id, report_type, charset)
      
      report_cols = store.base_report_cols.dup
      message_cols = store.base_message_cols.dup
      report_type.each do |etype|
        col = "#{store.col_name(etype.id)} #{etype.sql_type(store.sql_types)}"
        report_cols << col
        message_cols << col
      end
      
      store.transaction {
        store.create_table(store.table_name('reports'), *report_cols)
        store.create_table(store.table_name('messages'), *message_cols)
        store.create_table(store.table_name('attachments'),
                           "id          #{store.sql_types['serial']} primary key",
                           "name        #{store.sql_types['varchar'].vt(255)}",
                           "size        int",
                           "mimetype    #{store.sql_types['varchar'].vt(128)}",
                           "create_time #{store.sql_types['timestamp']}",
                           "data        #{store.sql_types['blob']}")
        
        store.execute() do |db|
          db.do("create index #{store.table_name('rid_index')} on #{store.table_name('messages')} (report_id)")
          if report_type['e_status'] then
            db.do("create index #{store.table_name('status_index')} on #{store.table_name('reports')} (e_status)")
          end
        end
      }
    end
    
    def init_dbi(driver_name, dbname, user, pass, args, params = {})
      @driver_url = BaseDBIStore3.create_driver_url(driver_name, dbname, args)
      @user = user
      @pass = pass
      @params = params
      @connection = nil
    end
    
    def table_opt()
      nil
    end
    
    def table_name(name)
      "#{@project_id}_#{name}"
    end
    
    def col_name(name)
      'e_' + name.downcase
    end
        
    def store_boolean(b)
      b
    end
    
    def load_boolean(d)
      (d == true || d == 1 || d == 'true' || d == 't' || d == 'yes' || d == 'y' || d == '1') ? true : false
    end
    
    def transaction(&block)
      execute do |db|
        db['AutoCommit'] = false
        db.transaction{ yield }
      end
    end
    
    def execute()
      if @connection then
        yield @connection
      else
        DBI.connect(@driver_url, @user, @pass, @params) do |db|
          begin
            @connection = db
            @params.each {|k, v| db[k] = v}
            yield db
          ensure
            @connection = nil
          end
        end
      end
    end
    
    def create_table(name, *cols)
      execute do |db|
        query = "create table #{name} (#{cols.join(', ')}) #{table_opt()}"
        db.do(query)
      end
    end
    
    def add_element_type(report_type, etype)
      execute do |db|
        db.do("alter table #{table_name('reports')} add column #{col_name(etype.id)} #{etype.sql_type(sql_types())}")
        db.do("alter table #{table_name('messages')} add column #{col_name(etype.id)} #{etype.sql_type(sql_types())}")
      end
    end
    
    def delete_element_type(report_type, etype_id)
      execute do |db|
        db.do("alter table #{table_name('reports')} drop column #{col_name(etype_id)}")
        db.do("alter table #{table_name('messages')} drop column #{col_name(etype_id)}")
      end
    end
    
    def change_element_type(report_type)
      # nothing to do
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
        report.each do |message|
          next unless message.modified?
          cols = [sql_time(message.time)]
          report.type.each{|etype| cols << store_kconv(message[etype.id])}
          cols << message.option_str()
          cols << store_boolean(message.hide?)
          cols << message.ip_addr
          db.do(message_sql, *cols)
          message.modified = false
        end
        update_report_table(db, report)
      end
    end
    
    def update_report_table(db, report)
      col_names = report.type.collect{|etype| col_name(etype.id)}
      col_names = col_names + ['author', 'size', 'visible_size', 'create_time', 'modify_time']
      
      values = []
      report.ensure()
      report.type.each{|etype| values << store_kconv(report[etype.id])}
      values = values + [store_kconv(report.author.value), report.size, report.visible_size]
      unless report.hide? then
        values << sql_time(report.first.time)
        values << sql_time(report.last.time)
      else
        values << sql_time(report.at(1).time)
        values << sql_time(report.at(report.size).time)
      end
      
      holders = col_names.collect{|name| "#{name} = ?"}
      sql = "update #{table_name('reports')} SET #{holders.join(', ')} where id = #{report.id}"
      
      db.do(sql, *values)
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
    
    def update(report)
      message_col_names, message_cols = build_message_col_holder(report)
      
      message_sql = "update #{table_name('messages')} set "
      message_sql += message_col_names.collect{|name| "#{name} = ?"}.join(", ")
      message_sql += " where id = ?"
      
      execute do |db|
        report.each do |message|
          next unless message.modified?
          values = []
          report.type.each{|etype| values << store_kconv(message[etype.id])}
          values << message.option_str()
          values << store_boolean(message.hide?)
          values << message.ip_addr
          values << message.uid
          db.do(message_sql, *values)
          message.modified = false
        end
        
        update_report_table(db, report)
      end
    end
    
    def remake(report)
      execute do |db|
        db.do("delete from #{table_name('messages')} where report_id = #{report.id}")
      end
      report.each {|message| message.modified = true}
      store(report)
    end
    
    def load(report_type, id)
      execute do |db|
        report = Report.new(report_type, id)
        message_id = 0
        
        db.select_all("select * from #{table_name('messages')} where report_id = #{id} order by id").each do |row|
          message = Message.new(report_type, message_id)
          
          report_type.each {|etype| message[etype.id] = load_kconv(row[col_name(etype.id)]) }
          message.uid  = row['id']
          message.time = load_time(row['create_time'])
          message.hide = load_boolean(row['hide'])
          message.ip_addr = row['ip_addr'] || ""
          message.set_option_str(row['k_options'])
          message.modified = false
          
          report.add_message(message)
          message_id += 1
        end
        
        if message_id == 0 then
          raise ParameterError, MessageBundle[:err_invalid_report_id] % id.to_s
        end
        
        report.ensure()
        report
      end
    end
    
    def size()
      size = nil
      execute do |db|
        size = db.select_one("select count(id) from #{table_name('reports')}")[0].to_i        
        Logger.debug('DBI', "size: report count(id) = #{size}")
      end
      size
    end
    
    def each(report_type, &block)
      execute do |db|
        db.select_all("select id from #{table_name('reports')}").each do |row|
          block.call(load(report_type, row['id']))
        end
      end
    end
    
    def search(report_type, cond_attr, cond_other, and_op, limit, offset, order)
      id = nil
      attr_id = []
      execute do |db|
        if cond_attr && cond_attr.size > 0 then
          cond_attr_query = cond_attr.to_sql3(sql_search_op()) {|eid, word|
            [col_name(eid), db.quote(store_kconv(word))]
          }
          rorder = (order == 'report_id') ? 'id' : order
          query = "select id from #{table_name('reports')} where (#{cond_attr_query}) order by #{rorder}"
          attr_id = do_search_query(db, query, 'id', offset, limit)
          id = attr_id
        end
        
        other_id = []
        if cond_other && cond_other.size > 0 then
          cond_other_query = cond_other.to_sql3(sql_search_op()) {|eid, word|
            [col_name(eid), db.quote(store_kconv(word))]
          }
          query = "select DISTINCT report_id from #{table_name('messages')} where #{cond_other_query} order by #{order}"
          other_id = do_search_query(db, query, 'report_id', offset, limit)
          if id.nil? then
            id = other_id
          else
            id = and_op ? (attr_id & other_id) : (attr_id | other_id)
          end
        end
        
        if id.nil? then
          # no condition, select all.
          query = "select DISTINCT report_id from #{table_name('messages')} order by report_id"
          id = do_search_query(db, query, 'report_id', offset, limit)
        end
      end
      
      reports = load_report_entries(id[offset, limit])
      Store::SearchResult.new(id.size, limit, offset, reports)
    end
            
    def collect_reports(report_type, attr_id)
      ReportCollectionProxy.new(self, attr_id)
    end
    
    def collect_reports_with_choice(attr_id, choice_id)      
      reports = nil
      execute do |db|
        query =  "select * from #{table_name('reports')}"
        query += " where #{col_name(attr_id)} = '#{store_kconv(choice_id)}' order by id"
        
        reports = []
        db.select_all(query) do |row|
          reports << create_report_entry(row)
        end
      end
      reports
    end
    
    def count_reports(report_type, attr_id)
      counts = Hash.new(0)
      
      query = "select #{col_name(attr_id)} from #{table_name('reports')}"
      execute do |db|
        db.execute(query) do |cursor|
          while row = cursor.fetch do
            attrs = load_kconv(row[col_name(attr_id)].to_s)
            attrs.split(/,\n/).each {|attr| counts[attr] += 1}
          end
        end
      end
      
      counts
    end
    
    def store_attachment(attachment, fileinfo)
      execute do |db|
        attach_id = nil
        db.transaction {
          name = fileinfo.name
          size = fileinfo.size
          ctime = sql_time(attachment.stat.ctime)
          data = escape_binary(attachment.read)
          
          sql =  "insert into #{table_name('attachments')} (name,size,create_time,data)"
          sql += "  values (?,?,?,?)"
          
          db.do(sql, name, size, ctime, data)
          attach_id = db.select_one("select max(id) from #{table_name('attachments')}")[0].to_i
        }
        attach_id
      end
    end
    
    def open_attachment(attach_id)
      execute do |db|
        query = "select data from #{table_name('attachments')} where id = #{attach_id}"
        data = unescape_binary(db.select_one(query)[0])
        
        file = Tempfile.new('kagemai_attach_export')
        file.binmode
        file.write(data)
        file.rewind
        
        file
      end
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
    
    
    private
        
    def build_message_col_holder(report)
      message_col_names = []
      message_cols = []
      report.type.each do |etype|
        message_col_names << col_name(etype.id)
        message_cols << '?'
      end
      message_col_names << 'k_options'
      message_cols << '?'
      message_col_names << 'hide'
      message_cols << '?'
      message_col_names << 'ip_addr'
      message_cols << '?'
      
      [message_col_names, message_cols]
    end
    
    def sql_time(time)
      time.format()
    end
    
    def load_time(value)
      value.to_time()
    end
    
    def escape_binary(v)
      v
    end
    
    def unescape_binary(v)
      v
    end
    
    # convert encoding from view to db
    def store_kconv(view_encoded_str)
      view_encoded_str
    end
    
    # convert encoding from db to view
    def load_kconv(db_encoded_str)
      db_encoded_str
    end
    
    def do_search_query(db, query, col, offset, limit)
      Logger.debug('DBI', KKconv::conv(query, KKconv::EUC))
      db.select_all(query).collect{|row| row[0]}
    end
        
    def do_search_query2(db, query, col, offset, limit)
      result = []
      db.execute(query) do |cursor|
        row = cursor.fetch_scroll(DBI::SQL_FETCH_ABSOLUTE, offset)
        break unless row
        
        result << row[col].to_i
        (limit - offset - 1).times {
          row = cursor.fetch()
          break unless row
          result << row[col].to_i
        }
      end
      
      result
    end
    
    class ReportEntry < Report
      def initialize(type, id, size, ctime, mtime, author, values)
        super(type, id)
        @size   = size
        @create_time = ctime.format
        
        @first = @last = Message.new(type)
        type.each do |etype|
          @first[etype.id] = values[etype.id]
        end
        @first.time = mtime
        @first.name = author
      end
      attr_reader :size, :create_time
      
      def visible_size()
        @size
      end
      
      def add_message(message) raise InvalidOperation; end
      def each(&block) raise InvalidOperation; end
      def at(id) raise InvalidOperation; end
    end
    
    def create_report_entry(row)
      id = row['id'].to_i
      size = row['visible_size'].to_i
      ctime = load_time(row['create_time'])
      mtime = load_time(row['modify_time'])
      author = load_kconv(row['author'])
      
      values = {}
      @report_type.each {|etype| values[etype.id] = load_kconv(row[col_name(etype.id)])}
      
      ReportEntry.new(@report_type, id, size, ctime, mtime, author, values)
    end
    
    def load_report_entries(id)
      return [] if id.size == 0
      
      reports = []
      execute do |db|
        sql = "select * from #{table_name('reports')} where id in (#{id.join(',')}) order by id"
        db.select_all(sql) do |row|
          reports << create_report_entry(row)
        end
      end
      reports
      
    end
    
    def load_report_entry(id)
      load_report_entries([id])
    end
    
  end
end
