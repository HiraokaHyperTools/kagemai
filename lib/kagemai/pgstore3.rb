=begin
  PostgresStore3 - PostgreSQL report manager.
=end

require 'kagemai/dbistore3'
require 'kagemai/util'

module Kagemai
  class PostgresStore3 < BaseDBIStore3
    
    DBI_DRIVER_NAME = 'Pg'
    
    SQL_TYPES = {
      'serial'    => SQLType.new('serial'),
      'int'       => SQLType.new('int'),
      'boolean'   => SQLType.new('boolean'),
      'varchar'   => SQLType.new('varchar'),
      'text'      => SQLType.new('text'),
      'timestamp' => SQLType.new('timestamp with time zone'),
      'date'      => SQLType.new('date'),
      'blob'      => SQLType.new('bytea')
    }
    
    SQL_SEARCH_OP = {
      true     => 'true',
      false    => 'false',
      'regexp' => '~',
    }
    
    def self.disp_name()
      'PostgresStore3 (EUC, obsolete)'
    end

    def self.obsolete?()
      true
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
    
    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      init_dbi(DBI_DRIVER_NAME, 
               Config[:postgres_dbname], 
               Config[:postgres_user], 
               Config[:postgres_pass], 
               self.class.database_args())
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
          db.do("alter table #{table_name('reports')} drop column #{col_name(etype_id)}")
          db.do("alter table #{table_name('messages')} drop column #{col_name(etype_id)}")
        else
          raise InvalidOperationError, "Sorry, your PostgreSQL does not support drop column. Try convert another save format and delete it."
        end
      end
      change_element_type(report_type)
    end
    
    def escape_binary(v)
      [v].pack('m')
      #"E'" + v.unpack('C*').collect{|c| "\\\\%03o" % c}.join + "'"
    end
    
    def unescape_binary(v)
      v.unpack('m')[0]
      #v.scan(/\\(\d\d\d)/).collect{|o| o[0].oct}.pack("C*")
    end
    
  end
    
end
