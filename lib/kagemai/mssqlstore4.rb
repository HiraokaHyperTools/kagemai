=begin
  MSSQLStore4 - SQL Server report manager
=end

require 'kagemai/mssqlstore3'

module Kagemai
  class MSSqlStore4 < MSSqlStore3
    def self.disp_name()
      'MSSqlStore4'
    end
    
    def self.obsolete?()
      false
    end
  end
end
