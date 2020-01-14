=begin
  MySQLStore - MySQL report manager.
  
  Copyright(C) 2002, 2003, 2005 FUKUOKA Tomoyuki.
  Copyright(C) 2004, NOGUCHI Shingo
  
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
  
  $Id: mysqlstore.rb 412 2008-02-23 14:54:23Z fukuoka $
=end

require 'kagemai/store'
require 'kagemai/dbistore'
require 'kagemai/util'
require 'tempfile'
require 'time'

module Kagemai  
  class MySQLStore < Store
    include BaseDBIStore
    
    def self.obsolete?()
      true
    end
    
    DBI_DRIVER_NAME = 'Mysql'

    SQL_TYPES = {
      'varchar' => SQLType.new('varchar', 'binary'),
      'text'    => SQLType.new('blob', nil),
    }
    
    SQL_SEARCH_OP = {
      true     => "'1'",
      false    => "'0'",
      'regexp' => 'regexp',
    }

    def self.disp_name()
      'old MySQLStore(obsolete)'
    end
    
    def self.description()
      MessageBundle[:MySQLStore]
    end
    
    def self.database_args()
      args = {}
      args['host'] = Config[:mysql_host] unless Config[:mysql_host].to_s.empty?
      args['port'] = Config[:mysql_port] unless Config[:mysql_port].to_s.empty?
      args
    end
    
    def self.db_charset(charset)
      charset == 'EUC-JP' ? 'EUC_JP' : 'SQL_ASCII'
    end
    
    def self.create(dir, project_id, report_type, charset)
      begin
        init_tables(dir, project_id, report_type, charset)
      rescue Exception
        destroy(dir, project_id)
        raise
      end
    end
    
    def self.destroy(dir, project_id)
      tables = %w(reports messages attachments)
      store  = self.new(dir, project_id, nil, nil)
      store.execute() do |db|
        tables.each do |table|
          db.do("drop table #{store.table_name(table)}")
        end
      end
    end
    
    BASE_MESSAGE_COLS = [
      'id int auto_increment primary key',
      'report_id int',
      'create_time datetime',
      "#{BaseDBIStore::MESSAGE_OPTION_COL_NAME} varchar(#{MESSAGE_OPTION_MAX_SIZE}) binary"
    ]
    
    def self.init_tables(dir, project_id, report_type, charset)
      store = self.new(dir, project_id, report_type, charset)
      table_opt =  "type = myisam"
      table_opt += " default character set ujis" if store.mysql_version >= "4.1.0"
      
      store.transaction {      
        store.create_table(store.table_name('reports'), 
                           table_opt,
                           'id int primary key',
                           'size int',
                           'first_message_id int',
                           'last_message_id int',
                           'modify_time datetime',
                           'create_time datetime')
        
        message_cols = BASE_MESSAGE_COLS.dup
        report_type.each do |etype|
          message_cols << "#{store.col_name(etype.id)} #{etype.sql_type(SQL_TYPES)}"
        end
        
        store.create_table(store.table_name('messages'), table_opt, *message_cols)
        
        store.create_table(store.table_name('attachments'),
                           table_opt,
                           'id int auto_increment primary key',
                           'name varchar(255) binary',
                           'size integer',
                           'mimetype varchar(128) binary',
                           'create_time datetime',
                           'data longblob')
        
        store.execute() do |db|
          db.do("create index #{store.table_name('rid_index')} on #{store.table_name('messages')} (report_id)")
        end
      }
    end
    
    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      @has_transaction = false
      init_dbi(DBI_DRIVER_NAME, 
               Config[:mysql_dbname], 
               Config[:mysql_user], 
               Config[:mysql_pass], 
               self.class.database_args())
      check_version()
      check_timezone()
    end
    
    def check_version()
      DBI.connect(@driver_url, @user, @pass, @params) do |db|
        @params.each {|k, v| db[k] = v}
        @mysql_version = db.select_one("select version()")[0]
      end
    end
    attr_reader :mysql_version
    
    def check_timezone()
      DBI.connect(@driver_url, @user, @pass, @params) do |db|
        @params.each {|k, v| db[k] = v}
        dt = db.select_one("select now()")[0]
        if dt.kind_of?(String) then
          dt = Time.parse(dt)
        end
        mysql_now   = Time.local(dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec)
        @local_time = (Time.now - mysql_now).abs < (60 * 30)
      end
    end
    
    def sql_types()
      MySQLStore::SQL_TYPES
    end
    
    def sql_op(key)
      MySQLStore::SQL_SEARCH_OP[key]
    end
    
    def table_name(name)
      "#{@project_id}_#{name}"
    end
    
    def execute()
      if @connection then
        yield @connection
      else
        DBI.connect(@driver_url, @user, @pass, @params) do |db|
          begin
            @connection = db
            @params.each {|k, v| db[k] = v}
            db.do("set names ujis") if @mysql_version >= "4.1.0"
            yield db
          ensure
            @connection = nil
          end
        end
      end
    end
    
    def transaction(&block)
      yield
    end
    
    def next_id()
      next_id = nil
      execute do |db|
        next_id = db.select_one("select max(id) from #{table_name('reports')}")[0].to_i + 1
        db.do("insert into #{table_name('reports')} (id, size) values (#{next_id}, 0)")
      end
      next_id
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
    
    def store_attachment(attachment, fileinfo)
      execute do |db|
        attach_id = nil
        db.transaction {
          name = fileinfo.name
          size = fileinfo.size
          ctime = sql_time(attachment.stat.ctime)
          data = attachment.read
          
          sql =  "insert into #{table_name('attachments')} (name,size,create_time,data)"
          sql += "  values (?, ?,?,?)"
          
          db.do(sql, name, size, ctime ,data)
          attach_id = db.func(:insert_id)
        }
        attach_id
      end
    end
    
    def open_attachment(attach_id)
      execute do |db|        
        query = "select data from #{table_name('attachments')} where id = #{attach_id}"
        data = db.select_one(query)[0]
        
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
    
    def create_last_message_view(report_type)
      # do nothing
    end
    
    def drop_last_message_view()
      # do nothing
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
        query += " where #{col_name(attr_id)} regexp '#{choice_id}' and (#{where_clause}) order by id"
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
    
    def sql_time(time)
      if @local_time then
        time.format()
      else
        time.utc.format()
      end
    end
    
  end
end
