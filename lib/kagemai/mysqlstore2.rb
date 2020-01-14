=begin
  MySQLStore - MySQL report manager.
  
  Copyright(C) 2002-2008 FUKUOKA Tomoyuki.
  Copyright(C) 2004, NOGUCHI Shingo
=end

require 'kagemai/store'
require 'kagemai/dbistore2'
require 'kagemai/util'
require 'tempfile'
require 'time'

module Kagemai  
  class MySQLStore2 < Store
    include BaseDBIStore2
    
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

    def self.obsolete?()
      true
    end

    def self.disp_name()
      'old MySQLStore2(obsolete)'
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
      rescue Exception => e
        destroy(dir, project_id)
        raise e
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
      'hide tinyint(1)',
      "#{BaseDBIStore::MESSAGE_OPTION_COL_NAME} varchar(#{MESSAGE_OPTION_MAX_SIZE}) binary"
    ]
    
    def self.init_tables(dir, project_id, report_type, charset)
      store = self.new(dir, project_id, report_type, charset)
      table_opt =  "type = innodb"
      table_opt += " default character set ujis" if store.mysql_version >= "4.1.0"
      
      store.transaction {      
        store.create_table(store.table_name('reports'), 
                           table_opt,
                           'id int primary key',
                           'size int',
                           'visible_size int',
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
          db.do("create index #{store.table_name('status_index')} on #{store.table_name('messages')} (e_status)")
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
    
    # mysql has no boolean type
    def store_boolean(b)
      b ? 1 : 0
    end
    
    def load_boolean(d)
      (d == '1' || d == 1) ? true : false
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
        
    def sql_time(time)
      if @local_time then
        time.format()
      else
        time.utc.format()
      end
    end

    def store_attachment(attachment, fileinfo)
      execute do |db|
        attach_id = nil
        db.transaction {
          name = File.basename(attachment.original_filename.gsub(/\\/, '/'))
          size = attachment.stat.size
          ctime = sql_time(attachment.stat.ctime)
          data = attachment.read
          
          sql =  "insert into #{table_name('attachments')} (name,size,create_time,data)"
          sql += "  values (?,?,?,?)"
          
          db.do(sql, name, size, ctime, data)
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
    
  end
end
