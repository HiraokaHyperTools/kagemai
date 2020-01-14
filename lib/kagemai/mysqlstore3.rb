=begin
  MySQLStore3 - MySQL report manager.
  
  Copyright(C) 2008 FUKUOKA Tomoyuki.
  Copyright(C) 2004, NOGUCHI Shingo
=end

require 'kagemai/dbistore3'
require 'kagemai/util'
require 'time'

module Kagemai  
  class MySQLStore3 < BaseDBIStore3
    DBI_DRIVER_NAME = 'Mysql'
    
    SQL_TYPES = {
      'serial'    => SQLType.new('int auto_increment'),
      'int'       => SQLType.new('int'),
      'boolean'   => SQLType.new('tinyint(1)'),
      'varchar'   => SQLType.new('varchar', 'binary'),
      'text'      => SQLType.new('text'),
      'timestamp' => SQLType.new('datetime'),
      'date'      => SQLType.new('date'),
      'blob'      => SQLType.new('longblob'),
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
      'MySQLStore3 (EUC, obsolete)'
    end
    
    def self.description()
      MessageBundle[:MySQLStore]
    end
        
    def initialize(dir, project_id, report_type, charset)
      super(dir, project_id, report_type, charset)
      @has_transaction = false
      init_dbi(DBI_DRIVER_NAME, 
               Config[:mysql_dbname], 
               Config[:mysql_user], 
               Config[:mysql_pass], 
               database_args())
      check_version()
      check_timezone()
    end
    
    def database_args()
      args = {}
      args['host'] = Config[:mysql_host] unless Config[:mysql_host].to_s.empty?
      args['port'] = Config[:mysql_port] unless Config[:mysql_port].to_s.empty?
      args
    end
    private :database_args
    
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

    def load_time(value)
      time = value.to_time()
      if time.utc? && @local_time then
        Time.local(*time.to_a)
      else
        time
      end
    end
    
  end
end
