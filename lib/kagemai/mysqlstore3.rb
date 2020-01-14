=begin
  MySQLStore3 - MySQL report manager.
  
  Copyright(C) 2008 FUKUOKA Tomoyuki.
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
  
  $Id: mysqlstore3.rb 423 2008-02-24 15:10:28Z fukuoka $
=end

require 'kagemai/store'
require 'kagemai/dbistore3'
require 'kagemai/util'
require 'time'

module Kagemai  
  class MySQLStore3 < Store
    include BaseDBIStore3
    
    DBI_DRIVER_NAME = 'Mysql'
    
    SQL_TYPES = {
      'serial'    => SQLType.new('int auto_increment'),
      'boolean'   => SQLType.new('tinyint(1)'),
      'varchar'   => SQLType.new('varchar', 'binary'),
      'text'      => SQLType.new('text'),
      'timestamp' => SQLType.new('datetime'),
      'blob'      => SQLType.new('longblob'),
    }
    
    SQL_SEARCH_OP = {
      true     => "'1'",
      false    => "'0'",
      'regexp' => 'regexp',
    }
    
    def self.disp_name()
      'MySQLStore3'
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
    
    def self.create(dir, project_id, report_type, charset)
      BaseDBIStore3.create(self, dir, project_id, report_type, charset)
    end
    
    def self.destroy(dir, project_id)
      BaseDBIStore3.destroy(self, dir, project_id)
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

    def sql_types()
      SQL_TYPES
    end
    
    def sql_op(key)
      SQL_SEARCH_OP[key]
    end
    
    def sql_search_op()
      SQL_SEARCH_OP
    end
    
    def table_opt()
      opt =  "type = innodb"
      opt += " default character set ujis" if @mysql_version >= "4.1.0"
      opt
    end
    
    # mysql has no boolean type
    def store_boolean(b)
      b ? 1 : 0
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
    
    def sql_time(time)
      if @local_time then
        time.format()
      else
        time.utc.format()
      end
    end    
    
  end
end
