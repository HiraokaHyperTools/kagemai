=begin
  PostgresStore3 - PostgreSQL report manager.

  Copyright(C) 2008 FUKUOKA Tomoyuki.
  
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
  
  $Id: pgstore3.rb 384 2008-02-20 23:21:52Z fukuoka $
=end

require 'kagemai/store'
require 'kagemai/dbistore3'
require 'kagemai/util'

module Kagemai
  class PostgresStore3 < Store
    include BaseDBIStore3
    
    DBI_DRIVER_NAME = 'Pg'
    
    SQL_TYPES = {
      'serial'    => SQLType.new('serial'),
      'boolean'   => SQLType.new('boolean'),
      'varchar'   => SQLType.new('varchar'),
      'text'      => SQLType.new('text'),
      'timestamp' => SQLType.new('timestamp with time zone'),
      'blob'      => SQLType.new('bytea')
    }
    
    SQL_SEARCH_OP = {
      true     => 'true',
      false    => 'false',
      'regexp' => '~',
    }
    
    def self.disp_name()
      'PostgresStore3'
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
    
    def self.create(dir, project_id, report_type, charset)
      BaseDBIStore3.create(self, dir, project_id, report_type, charset)
    end
    
    def self.destroy(dir, project_id)
      BaseDBIStore3.destroy(self, dir, project_id)
    end
    
    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      init_dbi(DBI_DRIVER_NAME, 
               Config[:postgres_dbname], 
               Config[:postgres_user], 
               Config[:postgres_pass], 
               self.class.database_args())
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
