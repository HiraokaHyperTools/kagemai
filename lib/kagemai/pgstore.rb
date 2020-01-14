=begin
  PostgresStore - PostgreSQL report manager.
=end

require 'kagemai/store'
require 'kagemai/dbistore'
require 'kagemai/util'
require 'tempfile'

class PGconn
  alias old_exec exec

  def exec(sql)
    if block_given? then
      begin
        res = old_exec(sql)
        yield res
      ensure
        res.clear()
      end
    else
      old_exec(sql)
    end
  end
end

module Kagemai
  class PostgresStore < Store
    include BaseDBIStore
    
    def self.obsolete?()
      true
    end
    
    DBI_DRIVER_NAME = 'Pg'
    WORK_DATABASE   = 'template1'

    def self.disp_name()
      'old PostgresStore(obsolete)'
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
      sql_opt = "with encoding = '#{db_charset(charset)}'"
      begin
        BaseDBIStore.create_database(DBI_DRIVER_NAME, 
                                     WORK_DATABASE, 
                                     project_id,   # database name
                                     Config[:postgres_user],
                                     Config[:postgres_pass],
                                     database_args(), 
                                     sql_opt)
        init_tables(dir, project_id, report_type, charset)
      rescue Exception
        destroy(dir, project_id)
        raise
      end
    end

    def self.destroy(dir, project_id)
      BaseDBIStore.drop_database(DBI_DRIVER_NAME, 
                                 WORK_DATABASE, 
                                 project_id,   # database name
                                 Config[:postgres_user],
                                 Config[:postgres_pass],
                                 database_args())
    end

    BASE_MESSAGE_COLS = [
      'id serial primary key',
      'report_id int',
      'create_time timestamp with time zone',
      "#{BaseDBIStore::MESSAGE_OPTION_COL_NAME} varchar(#{MESSAGE_OPTION_MAX_SIZE})"
    ]
    
    def self.init_tables(dir, project_id, report_type, charset)
      store = self.new(dir, project_id, report_type, charset)
      table_opt = nil
      
      store.transaction {      
        store.create_table('reports', 
                           table_opt,
                           'id serial primary key',
                           'size int',
                           'first_message_id int',
                           'last_message_id int',
                           'create_time timestamp with time zone',
                           'modify_time timestamp with time zone')
        
        message_cols = BASE_MESSAGE_COLS.dup
        report_type.each do |etype|
          message_cols << "#{store.col_name(etype.id)} #{etype.sql_type(SQL_TYPES)}"
        end
        
        store.create_table('messages', table_opt, *message_cols)
        
        store.create_table('attachments',
                           table_opt,
                           'id oid primary key',
                           'name varchar(256)',
                           'size integer',
                           'mimetype varchar(128)',
                           'create_time timestamp with time zone')
        
        store.execute() do |db|
          db.do("create index rid_index on messages (report_id)")
        end
        
        store.create_last_message_view(report_type)
      }
    end

    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      init_dbi(DBI_DRIVER_NAME, 
               project_id, 
               Config[:postgres_user], 
               Config[:postgres_pass], 
               self.class.database_args())
    end
    
    def col_name(name)
      name.downcase
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
          drop_last_message_view()
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
      
      db.do("create table temp as select #{scols.join(', ')} from messages")
      db.do("drop table messages")
      db.do("drop sequence messages_id_seq")
      db.do("create table messages (#{ccols.join(', ')})")
      db.do("insert into messages select * from temp")
      db.do("drop table temp")
    end
    
    def store_with_id(report)
      execute do |db|
        nid = db.select_one("select setval('reports_id_seq', #{report.id}, false)")[0].to_i
      end
      next_id()
      store(report)
    end
    
    def store_attachment(attachment, fileinfo)
      execute do |db|
        oid = nil
        db.transaction {
          pg_large = db.func(:blob_import, attachment.path)
          oid = pg_large.oid          
          name = fileinfo.name
          size = fileinfo.size
          ctime = sql_time(attachment.stat.ctime)
          
          sql  = "insert into attachments (id,name,size,create_time)"
          sql += "  values (?,?,?,?)"
          db.do(sql, oid, name, size, ctime)
        }
        oid
      end
    end
    
    def open_attachment(seq_id)
      execute do |db|
        oid = seq_id
        file = Tempfile.new('kagemai_lo_export')
        path = file.path
        file.close
        
        db.transaction {
          db.func(:blob_export, oid, path)
        }
        
        file.open
        file
      end
    end
    
    def each_attachment()
      execute do |db|
        db.select_all('select id from attachments') do |row|
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
    
    def pg_exec(conn, sql)
      res = conn.exec(sql)
      if block_given? then
        begin
          yield res
        ensure
          res.clear
        end
      else
        res
      end
    end

  end
end
