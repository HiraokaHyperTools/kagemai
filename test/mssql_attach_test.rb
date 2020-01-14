require 'test/unit'

require 'kagemai/reporttype'
require 'kagemai/report'
require 'kagemai/message'

do_mysql_test = false
begin
  if Kagemai::Config[:enable_mssql] && /^Provider/ =~ Config[:mssql_dsn] then
    require 'dbi'
    require 'DBD/ADO/ADO'
    require 'kagemai/mssqlstore4'
    do_mssql_test = true
  end
rescue LoadError, NameError
end

if do_mssql_test then
  include Kagemai
  
  class TestMSSqlStoreAttach < Test::Unit::TestCase
    def setup()
      Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
      
      @project_id = 'kagemai_unittest'
      @report_type = ReportType.load('test/testfile/rtype2.xml')
      @charset = 'UTF-8'
      
      MSSqlStore4.create(nil, @project_id, @report_type, @charset)
      @store = MSSqlStore4.new(nil, @project_id, @report_type, @charset)
    end
    
    def teardown()
      MSSqlStore4.destroy(nil, @project_id)
    end
    
    def test_store_attachment()
      original_filename = 'test/testfile/mail/mail1.txt'
      
      attachment = File.open(original_filename, 'rb')
      expect = attachment.read
      attachment.rewind
      
      fileinfo = Store::FileInfo.new(original_filename, expect.size)
      oid = @store.store_attachment(attachment, fileinfo)
      assert_not_nil(oid)
        
      file = @store.open_attachment(oid)
      
      assert_equal(expect.inspect, file.read.inspect)
    end

    def test_store_attachment_bin()
      original_filename = 'test/testfile/sample.gif'
      
      attachment = File.open(original_filename, 'rb')
      expect = attachment.read
      attachment.rewind
      
      fileinfo = Store::FileInfo.new(original_filename, expect.size)
      oid = @store.store_attachment(attachment, fileinfo)
      assert_not_nil(oid)
        
      file = @store.open_attachment(oid)
      
      assert_equal(expect.inspect, file.read.inspect)
    end
    
  end
end
