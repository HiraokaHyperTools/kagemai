=begin
  MSSQLStore3 - SQL Server report manager
  Copyright(C) 2008 FUKUOKA Tomoyuki.
=end

require 'kagemai/dbistore3'
require 'kagemai/util'
require 'kagemai/kconv'

module Kagemai
  class MSSqlStore3 < BaseDBIStore3
    
    SQL_TYPES = {
      'serial'    => SQLType.new('int identity'),
      'int'       => SQLType.new('int'),
      'boolean'   => SQLType.new('tinyint'),
      'varchar'   => SQLType.new('nvarchar'),
      'text'      => SQLType.new('ntext'),
      'timestamp' => SQLType.new('datetime'),
      'date'      => SQLType.new('datetime'),
      'blob'      => SQLType.new('varchar(max)')
    }
    
    SQL_SEARCH_OP = {
      true     => '(1 = 1)',
      false    => '(1 = 0)',
      'regexp' => '~',
    }
    
    def self.obsolete?()
      true
    end
    
    def self.disp_name()
      'MSSqlStore3 (obsolete)'
    end
    
    def self.description()
      MessageBundle[:MSSqlStore]
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
    
    def increment_view_count(report_id)
      execute do |db|
        db['AutoCommit'] = true
        query = "UPDATE #{table_name('reports')} SET view_count=view_count+1 WHERE id=?"
        db.do(query, report_id)
      end
    end
    
    def add_element_type(report_type, etype)
      execute do |db|
        type = etype.sql_type(sql_types())
        db.do("alter table #{table_name('reports')} add #{col_name(etype.id)} #{type}")
        db.do("alter table #{table_name('messages')} add #{col_name(etype.id)} #{type}")
      end
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
      view_encoded_str
    end
    
    # convert encoding from db to view
    def load_kconv(db_encoded_str)
      db_encoded_str
    end
    
    def escape_binary(v)
      [v].pack('m')
    end
    
    def unescape_binary(v)
      v.unpack('m')[0]
    end
    
  end # MSSQLStore3
end # Kagemai
