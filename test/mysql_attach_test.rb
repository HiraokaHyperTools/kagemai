require 'test/unit'

require 'kagemai/reporttype'
require 'kagemai/report'
require 'kagemai/message'

do_mysql_test = false
begin
  require 'mysql'
  require 'kagemai/mysqlstore4'
  do_mysql_test = true
rescue LoadError
end

if do_mysql_test && Kagemai::Config[:enable_mysql] then
  include Kagemai

  class TestMySQLStoreAttach < Test::Unit::TestCase
    def setup()
      Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
      
      @project_id = 'kagemai_unittest'
      @report_type = ReportType.load('test/testfile/rtype2.xml')
      @charset = 'UTF-8'
      
      MySQLStore4.create(nil, @project_id, @report_type, @charset)
      @store = MySQLStore4.new(nil, @project_id, @report_type, @charset)
    end
    
    def teardown()
      MySQLStore4.destroy(nil, @project_id)
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
