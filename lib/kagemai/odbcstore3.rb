=begin
  ODBCStore3 - ODBC report manager
  Copyright(C) 2008 FUKUOKA Tomoyuki.
=end

require 'kagemai/store'
require 'kagemai/dbistore3'
require 'kagemai/util'
require 'kagemai/kconv'

module Kagemai
  class ODBCStore3 < BaseDBIStore3
    
    SQL_TYPES = {
      'serial'    => SQLType.new('int identity'),
      'int'       => SQLType.new('int'),
      'boolean'   => SQLType.new('tinyint'),
      'varchar'   => SQLType.new('nvarchar'),
      'text'      => SQLType.new('nvarchar(max)'),
      'timestamp' => SQLType.new('datetime'),
      'date'      => SQLType.new('datetime'),
      'blob'      => SQLType.new('varchar(max)')
    }
    
    SQL_SEARCH_OP = {
      true     => '(1 = 1)',
      false    => '(1 = 0)',
      'regexp' => '~',
    }
    
    def self.disp_name()
      'ODBCStore3'
    end

    def self.obsolete?()
      true
    end
    
    def self.description()
      MessageBundle[:ODBCStore]
    end
    
    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      @driver_url = "DBI:ODBC:#{Config[:mssql_dsn]}"
      @user = Config[:mssql_user]
      @pass = Config[:mssql_pass]
      @params = {}
      @connection = nil
    end
    
    def execute()
      if @connection then
        yield @connection
      else
        DBI.connect(@driver_url, @user, @pass, @params) do |db|
          begin
            @connection = db
            @params.each {|k, v| db[k] = v}
            db.do("set textsize " + text_size())
            yield db
          ensure
            @connection = nil
          end
        end
      end
    end
    
    def text_size()
      (Config[:max_attachment_size] * 1024).to_s
    end
    
    def add_element_type(report_type, etype)
      execute do |db|
        type = etype.sql_type(sql_types())
        db.do("alter table #{table_name('reports')} add #{col_name(etype.id)} #{type}")
        db.do("alter table #{table_name('messages')} add #{col_name(etype.id)} #{type}")
      end
    end
    
    def sql_types()
      SQL_TYPES
    end
    
    def sql_op(key)
      SQL_SEARCH_OP[key]
    end
    
    def sql_search_op()
      SQL_SEARCH_OP
    end
    
    def store_boolean(b)
      b ? 1 : 0
    end
        
    def load_time(value)
      value.to_time
    end
    
    # convert encoding from view to db
    def store_kconv(view_encoded_str)
      KKconv::conv(view_encoded_str, KKconv::SJIS, KKconv::UTF8)
    end
    
    # convert encoding from db to view
    def load_kconv(db_encoded_str)
      if !db_encoded_str.nil? then 
        KKconv::conv(db_encoded_str, KKconv::UTF8, KKconv::SJIS)
      else
        db_encoded_str
      end
    end
    
    def escape_binary(v)
      [v].pack('m')
    end
    
    def unescape_binary(v)
      v.unpack('m')[0]
    end
    
  end # ODBCStore3
end # Kagemai
