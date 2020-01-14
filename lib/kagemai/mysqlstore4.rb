=begin
  MySQLStore4 - MySQL report manager (UTF-8 version of MySQLStore3).
=end

require 'kagemai/mysqlstore3'

module Kagemai  
  class MySQLStore4 < MySQLStore3
    def self.disp_name()
      'MySQLStore4'
    end
    
    def self.obsolete?()
      false
    end
    
    def table_opt()
      "type = innodb default character set utf8"
    end
    
    def execute()
      if @connection then
        yield @connection
      else
        DBI.connect(@driver_url, @user, @pass, @params) do |db|
          begin
            @connection = db
            @params.each {|k, v| db[k] = v}
            db.do("set names utf8") if @mysql_version >= "4.1.0"
            yield db
          ensure
            @connection = nil
          end
        end
      end
    end
    
    # convert encoding from view to db
    def store_kconv(view_encoded_str)
      view_encoded_str
    end
    
    # convert encoding from db to view
    def load_kconv(db_encoded_str)
      db_encoded_str
    end
  end
end
