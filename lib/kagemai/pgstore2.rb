=begin
  PostgresStore2 - PostgreSQL report manager.
=end

require 'kagemai/store'
require 'kagemai/dbistore2'
require 'kagemai/util'
require 'tempfile'

module Kagemai
  class PostgresStore2 < Store
    include BaseDBIStore2
    
    DBI_DRIVER_NAME = 'Pg'

    def self.obsolete?()
      true
    end
    
    def self.disp_name()
      'old PostgresStore2(obsolete)'
    end

    def self.description()
      MessageBundle[:PostgresStore]
    end

    def self.database_args()
      args = {}
      args['host'] = Config[:postgres_host] unless Config[:postgres_host].to_s.empty?
      args['port'] = Config[:postgres_port] unless Config[:postgres_port].to_s.empty?
      args['options'] = Config[:postgres_opts] unless Config[:postgres_opts].to_s.empty?
      args
    end
    
    def self.db_charset(charset)
      charset == 'EUC-JP' ? 'EUC_JP' : 'SQL_ASCII'
    end
    
    def self.create(dir, project_id, report_type, charset)
      init_tables(dir, project_id, report_type, charset)
    end
    
    def self.destroy(dir, project_id)
      tables = %w(reports messages attachments)
      store  = self.new(dir, project_id, nil, nil)
      store.execute do |db|
        tables.each do |table|
          db.do("drop table #{store.table_name(table)}")
        end
      end
    end
    
    BASE_MESSAGE_COLS = [
      'id serial primary key',
      'report_id int',      
      'create_time timestamp with time zone',
      'hide boolean',
      "#{BaseDBIStore::MESSAGE_OPTION_COL_NAME} varchar(#{MESSAGE_OPTION_MAX_SIZE})"
    ]
    
    def self.init_tables(dir, project_id, report_type, charset)
      store = self.new(dir, project_id, report_type, charset)
      table_opt = nil
      
      store.transaction {      
        store.create_table(store.table_name('reports'),
                           table_opt,
                           'id int primary key',
                           'size int',
                           'visible_size int',
                           'first_message_id int',
                           'last_message_id int',
                           'create_time timestamp with time zone',
                           'modify_time timestamp with time zone')
        
        message_cols = BASE_MESSAGE_COLS.dup
        report_type.each do |etype|
          message_cols << "#{store.col_name(etype.id)} #{etype.sql_type(SQL_TYPES)}"
        end
        
        store.create_table(store.table_name('messages'), table_opt, *message_cols)
        
        store.create_table(store.table_name('attachments'),
                           table_opt,
                           'id serial primary key',
                           'name varchar(256)',
                           'size integer',
                           'mimetype varchar(128)',
                           'create_time timestamp with time zone',
                           'data bytea')
        
        store.execute() do |db|
          db.do("create index #{store.table_name('rid_index')} on #{store.table_name('messages')} (report_id)")
          db.do("create index #{store.table_name('status_index')} on #{store.table_name('messages')} (e_status)")
        end
      }
    end

    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      init_dbi(DBI_DRIVER_NAME, 
               Config[:postgres_dbname], 
               Config[:postgres_user], 
               Config[:postgres_pass], 
               self.class.database_args())
    end
    
    def table_name(name)
      "#{@project_id}_#{name}"
    end
    
    def load_boolean(d)
      (d == true || d == 'true' || d == 't' || d == 'yes' || d == 'y' || d == '1') ? true : false
    end
    
    def transaction(&block)
      execute do |db|
        db.transaction{ 
          db.do('set transaction isolation level serializable')
          yield
        }
      end
    end
    
    def delete_element_type(report_type, etype_id)
      has_drop_version = 'PostgreSQL 7.3.0'
      execute do |db|
        version = db.select_one('select version()')[0]
        if version[0...has_drop_version.size] >= has_drop_version then
          db.do("alter table messages drop column #{col_name(etype_id)}")
          db.do("update messages set title = title")
          create_last_message_view(report_type)
        else
          delete_element_type_by_dump(db, report_type, etype_id)
        end
      end
      change_element_type(report_type)
    end
    
    def delete_element_type_by_dump(db, report_type, etype_id)
      scols = [                     # for select
        'id',
        'report_id', 
        'create_time',
        BaseDBIStore::MESSAGE_OPTION_COL_NAME
      ]
      ccols = BASE_MESSAGE_COLS.dup # for create talbe
      report_type.each do |etype|
        next if etype.id == etype_id
        scols  << col_name(etype.id)
        ccols << "#{col_name(etype.id)} #{etype.sql_type(SQL_TYPES)}"
      end
      
      db.do("create table temp as select #{scols.join(', ')} from #{table_name(messages)}")
      db.do("drop table #{table_name(messages)}")
      db.do("drop sequence #{table_name(messages_id_seq)}")
      db.do("create table #{table_name(messages)} (#{ccols.join(', ')})")
      db.do("insert into #{table_name(messages)} select * from temp")
      db.do("drop table temp")
    end
    
    def store_attachment(attachment, fileinfo)
      execute do |db|
        attach_id = nil
        db.transaction {
          name = fileinfo.name
          size = fileinfo.size
          ctime = sql_time(attachment.stat.ctime)
          data = [attachment.read].pack('m')
          
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
        data = db.select_one(query)[0].unpack('m')[0]
        
        file = Tempfile.new('kagemai_attach_export')
        file.binmode
        file.write(data)
        file.rewind
        
        file
      end
    end
  end
end
