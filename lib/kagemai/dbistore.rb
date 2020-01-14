=begin
  BaseDBIStore - abstract DBI report manager
=end

require 'dbi'
require 'kagemai/logger'
require 'kagemai/searchcond'
require 'kagemai/dbiutil'

module Kagemai  
  module BaseDBIStore
    MESSAGE_OPTION_COL_NAME = 'k_options'
    MESSAGE_OPTION_MAX_SIZE = 255
  
    SQL_TYPES = {
      'varchar' => SQLType.new('varchar'),
      'text'    => SQLType.new('text'),
    }
    
    SQL_SEARCH_OP = {
      true     => 'true',
      false    => 'false',
      'regexp' => '~',
    }
    
    def self.create_driver_url(driver_name, dbname, args)
      db_args = args ? args.dup : {}
      db_args['database'] = dbname
      db_args_str = db_args.collect{|k, v| "#{k}=#{v}"}.join(';')

      "DBI:#{driver_name}:#{db_args_str}"
    end

    def self.create_database(driver_name, workdb, dbname, user, pass, args, sql_opt)
      driver_url = create_driver_url(driver_name, workdb, args)
      DBI.connect(driver_url, user, pass) do |db|
        db.do("create database \"#{dbname}\" #{sql_opt}")
      end
    end

    def self.drop_database(driver_name, workdb, dbname, user, pass, args)
      driver_url = create_driver_url(driver_name, workdb, args)
      DBI.connect(driver_url, user, pass) do |db|
        db.do("drop database \"#{dbname}\"")
      end
    end
    
    def init_dbi(driver_name, dbname, user, pass, args, params = {})
      @driver_url = BaseDBIStore.create_driver_url(driver_name, dbname, args)
      @user = user
      @pass = pass
      @params = params
      @connection = nil
    end
    
    def table_name(name)
      name
    end
    
    def col_name(name)
      'e_' + name.downcase
    end

    def sql_types()
      BaseDBIStore::SQL_TYPES
    end
    
    def sql_op(key)
      BaseDBIStore::SQL_SEARCH_OP[key]
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


    def create_table(name, opt, *cols)
      execute do |db|
        db.do("create table #{name} (#{cols.join(', ')}) #{opt}")
      end
    end
    
    def create_last_message_view(report_type)
      cols = [
        'messages.report_id', 
        'messages.id', 
        'reports.size', 
        'reports.create_time', 
        'reports.modify_time'
      ]
      report_type.each do |etype|
        cols << "messages.#{col_name(etype.id)}" if etype.report_attr
      end
      cond = "last_message_id = messages.id"

      query = "select #{cols.join(',')} from #{table_name('reports')}, messages where #{cond}"

      execute do |db|
        db.do("create view last_messages as #{query}")
      end
    end

    def drop_last_message_view()
      execute do |db|
        db.do('drop view last_messages')
      end
    end

    def store(report)
      report_cols = []
      report_cols << "size = #{report.size}"
      report_cols << "create_time = '#{sql_time(report.first.time)}'"
      report_cols << "modify_time = '#{sql_time(report.last.time)}'"
      
      message_col_names = []
      message_cols = []
      report.type.each do |etype|
        message_col_names << col_name(etype.id)
        message_cols << '?'
      end
      message_col_names << MESSAGE_OPTION_COL_NAME
      message_cols << '?'
      
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
            sth.execute(*cols)
            message.modified = false
          end
        end
        
        # get first_message_id
        first_message_id = nil
        sql = "select min(id) from #{table_name('messages')} where report_id = #{report.id}"
        first_message_id = db.select_one(sql)[0]
        
        # get last_message_id
        last_message_id = nil
        sql = "select max(id) from #{table_name('messages')} where report_id = #{report.id}"
        last_message_id = db.select_one(sql)[0]
        
        report_cols << "first_message_id = #{first_message_id}"
        report_cols << "last_message_id = #{last_message_id}"
        sql = "update #{table_name('reports')} SET #{report_cols.join(', ')} where id = #{report.id}"
        db.do(sql)
      end
    end

    def update(report)
      execute do |db|
        db.do("delete from #{table_name('messages')} where report_id = #{report.id}")
      end
      report.each {|message| message.modified = true}
      store(report)
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
          
          report_type.each {|etype| message[etype.id] = row[col_name(etype.id)] }
          message.time = row['create_time'].to_time()
          message.set_option_str(row[MESSAGE_OPTION_COL_NAME])
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
    
    def next_id()
      next_id = nil
      execute do |db|
        db.do("insert into #{table_name('reports')} (size) values (0)")
        if self.size > 0
          next_id = db.select_one("select max(id) from #{table_name('reports')}")[0].to_i
          Logger.debug('DBI', "next_id: report max(id) = #{next_id}")
        else
          next_id = 1
        end
      end
      next_id
    end
    
    def transaction(&block)
      execute do |db|
        db['AutoCommit'] = false if @has_transaction
        db.transaction{ yield }
      end
    end
        
    def add_element_type(report_type, etype)
      execute do |db|
        db.do("alter table #{table_name('messages')} add column #{col_name(etype.id)} #{etype.sql_type(sql_types())}")
      end
      change_element_type(report_type)
    end
    
    def delete_element_type(report_type, etype_id)
      execute do |db|
        db.do("alter table #{table_name('messages')} drop column #{col_name(etype_id)}")
      end
      change_element_type(report_type)
    end
    
    def change_element_type(report_type)
      drop_last_message_view()
      create_last_message_view(report_type)
    end
    
    def search(report_type, cond_attr, cond_other, and_op, limit, offset, order)
      id = nil
      attr_id = []
      if cond_attr && cond_attr.size > 0 then
        cond_attr_query = cond_attr.to_sql(SQL_SEARCH_OP) {|eid| col_name(eid)}
        query = "select report_id from #{table_name('last_messages')} where #{cond_attr_query} order by #{order}"
        execute do |db|
          db.select_all(query) do |row|
            attr_id << row['report_id'].to_i
          end
        end
        id = attr_id
      end

      other_id = []
      if cond_other && cond_other.size > 0 then
        cond_other_query = cond_other.to_sql(SQL_SEARCH_OP) {|eid| col_name(eid)}
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

    def load_dummies(report_type, id)
      return [] if id.size == 0
      
      reports = {}
      execute do |db|
        cols = 'id,first_message_id,last_message_id,size'

        sql = "select #{cols} from #{table_name('reports')} where id in (#{id.join(',')}) order by id"
        r_size = {}
        mid = []
        db.select_all(sql) do |tuple|
          rid = tuple['id'].to_i
          mid << tuple['first_message_id'].to_i 
          mid << tuple['last_message_id'].to_i 
          r_size[rid] = tuple['size']
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
    
    def load_dummy(report_type, report_id)
      load_dummies(report_type, [report_id])[0]
    end
    
    def collect_reports(report_type, attr_id)
      ReportCollectionProxy.new(self, attr_id)
    end
    
    def collect_reports_with_choice(attr_id, choice_id)      
      reports = nil
      execute do |db|
        query =  "select report_id from #{table_name('last_messages')}"
        query += " where #{col_name(attr_id)} ~ '#{choice_id}' order by report_id"
        rid_set = db.select_all(query)
        reports = rid_set.collect {|rid| load_dummy(@report_type, rid[0])}
      end
      reports
    end
    
    def count_reports(report_type, attr_id)
      counts = Hash.new(0)
      
      query = "select #{col_name(attr_id)} from #{table_name('last_messages')} order by report_id"
      execute do |db|
        db.select_all(query).each do |tuple|
          attrs = tuple[col_name(attr_id)].to_s
          attrs.split(/,\n/).each {|attr| counts[attr] += 1}
        end
      end
      
      counts
    end
        
    def sql_time(time)
      time.format()
    end
    
  end
end
