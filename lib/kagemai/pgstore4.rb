=begin
  PostgresStore4 - PostgreSQL report manager (UTF-8 version of PostgresStore3)
=end

require 'kagemai/pgstore3'

module Kagemai
  class PostgresStore4 < PostgresStore3
    def self.disp_name()
      'PostgresStore4'
    end
    
    def self.obsolete?()
      false
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
