=begin
  MSSQLStore3 - SQL Server report manager
  Copyright(C) 2008 FUKUOKA Tomoyuki.
=end

require 'kagemai/store'
require 'kagemai/dbistore3'
require 'kagemai/util'
require 'kagemai/kconv'

module Kagemai
  class MSSqlStore3 < Store
    include BaseDBIStore3
    
    SQL_TYPES = {
      'serial'    => SQLType.new('int identity'),
      'boolean'   => SQLType.new('tinyint'),
      'varchar'   => SQLType.new('nvarchar'),
      'text'      => SQLType.new('ntext'),
      'timestamp' => SQLType.new('datetime'),
      'blob'      => SQLType.new('varchar(max)')
    }
    
    SQL_SEARCH_OP = {
      true     => '(1 = 1)',
      false    => '(1 = 0)',
      'regexp' => '~',
    }
    
    def self.disp_name()
      'MSSqlStore3'
    end
    
    def self.description()
      MessageBundle[:MSSqlStore]
    end
    
    def self.create(dir, project_id, report_type, charset)
      BaseDBIStore3.create(self, dir, project_id, report_type, charset)
    end
    
    def self.destroy(dir, project_id)
      BaseDBIStore3.destroy(self, dir, project_id)
    end
    
    def initialize(dir, project_id, report_type, charset)
      WIN32OLE.codepage = WIN32OLE::CP_UTF8
      super(dir, project_id, report_type, charset)
      args = {
        'User Id'  => Config[:mssql_user],
        'Password' => Config[:mssql_pass],
      }
      @driver_url = "DBI:ADO:#{Config[:mssql_dsn]};" + args.collect{|k, v| "#{k}=#{v}"}.join(';')
      @user = ''
      @pass = ''
      @params = ''
      @connection = nil
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
    
    def load_boolean(d)
      d == 1 ? true : false
    end
    
    def load_time(value)
      Time.parsedate(value)
    end
    
    # convert encoding from view to db
    def store_kconv(view_encoded_str)
      KKconv::conv(view_encoded_str, KKconv::UTF8, KKconv::EUC)
    end
    
    # convert encoding from db to view
    def load_kconv(db_encoded_str)
      KKconv::conv(db_encoded_str, KKconv::EUC, KKconv::UTF8)
    end

    def escape_binary(v)
      [v].pack('m')
    end
    
    def unescape_binary(v)
      v.unpack('m')[0]
    end
    
  end # MSSQLStore3
end # Kagemai
