require 'test/unit'

require 'kagemai/reporttype'
require 'kagemai/report'
require 'kagemai/message'

do_mysql_test = false
begin
  require 'dbi'
  require 'mysql'
  require 'kagemai/mysqlstore4'
  do_mysql_test = true
rescue LoadError
end

if do_mysql_test && Kagemai::Config[:enable_mysql] then
  include Kagemai
  
  class TestMySQLStore < Test::Unit::TestCase
    def setup()
      Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
      
      @project_id = 'kagemai_unittest'
      @report_type = ReportType.load('test/testfile/rtype4.xml')
      @charset = 'UTF-8'
      
      @email = ['fukouka@daifukuya.com', 'tomoyuki@daifukuya.com']
      @body = ['hell world', 'hello dbi']
      @opt = [{'o1' => 'v1', 'o2' => true}, {'o3' => false}]
      
      @messages = []
      0.upto(1) do |i|
        msg = Message.new(@report_type) 
        msg['email'] = @email[i] 
        msg['message'] = @body[i]
        @opt[i].each{|k, v| msg.set_option(k, v)}
        @messages << msg
      end
      
      MySQLStore4.create(nil, @project_id, @report_type, @charset)
      @store = MySQLStore4.new(nil, @project_id, @report_type, @charset)
    end
    
    def teardown()
      MySQLStore4.destroy(nil, @project_id)
    end
    
    def test_nextid()
      assert_equal(1, @store.next_id())
    end
    
    def test_store()
      report_id = nil
      
      @store.transaction {
        report_id = @store.next_id
        report = Report.new(@report_type, report_id)
        report.add_message(@messages[0])
        report.add_message(@messages[1])
        @store.store(report)
      }
      
      report_rows = nil
      message_rows = nil
      @store.execute() do |db|
        report_rows = db.select_all("select * from #{@project_id}_reports")
        message_rows = db.select_all("select * from #{@project_id}_messages")
      end
      assert_equal(1, report_rows.size)
      assert_equal(2, message_rows.size)
      
      assert_equal(1, report_rows[0]['id'])
      
      count = 0
      0.upto(1) do |i|
        result = message_rows[i]
        msg = @messages[i]
        assert_equal(report_id, result['report_id'])
        assert_equal(count + 1, result['id'])
        assert_equal(msg['email'], result[@store.col_name('email')])
        assert_equal(msg['message'], result[@store.col_name('message')])
        count += 1
      end
    end
    
    def test_load
      report_id = nil
      report = nil
      @store.transaction {
        report_id = @store.next_id
        report = Report.new(@report_type, report_id)
        report.add_message(@messages[0])
        report.add_message(@messages[1])
        @store.store(report)
      }
      time = report.first.time
      
      report = @store.load(@report_type, report_id)
      assert_instance_of(Kagemai::Report, report)
      assert_equal(2, report.size)

      fmt = '%Y-%m-%d %H:%M:%S'
      assert_equal(time.strftime(fmt), report.first.time.strftime(fmt))
      
      report.each_with_index do |message, i|
        assert_equal(i + 1, message.id)
        assert_equal(@messages[i]['email'], message['email'])
        assert_equal(@messages[i]['message'], message['message'])
        
        opt = {}
        message.each_option{|k ,v| opt[k] = v}
        assert_equal(@opt[i], opt)
      end
    end
    
    def test_load2
      assert_raise(Kagemai::ParameterError) {
        @store.load(@report_type, 100)
      }
    end
    
    def test_update()
      report = nil
      report_id = nil
      
      message = @messages[0].dup
      @store.transaction {
        report_id = @store.next_id
        report = Report.new(@report_type, report_id)
        report.add_message(@messages[0])
        report.add_message(@messages[1])
        @store.store(report)
      }
      
      # for update, load message.uid
      report = @store.load(@report_type, report.id)
      
      report.last['email'] = 'kagemai_test@daifukuya.com'
      report.last.modified = true
      @store.transaction {
        @store.update(report)
      }
            
      report_rows = nil
      message_rows = nil
      @store.execute() do |db|
        report_rows = db.select_all("select * from #{@project_id}_reports order by id")
        message_rows = db.select_all("select * from #{@project_id}_messages order by id")
      end
      
      assert_equal(1, report_rows.size)
      assert_equal(2, message_rows.size)
      
      assert_equal(1, report_rows[0]['id'])
      
      email = [@email[0], 'kagemai_test@daifukuya.com']
      
      count = 0
      0.upto(1) do |i|
        result = message_rows[i]
        msg = @messages[i]
        assert_equal(report_id, result['report_id'])
        assert_equal(email[i], result[@store.col_name('email')])
        assert_equal(@body[i], result[@store.col_name('message')])
        count += 1
      end
    end
    
    def test_remake()
      report = nil
      report_id = nil
      
      message = @messages[0].dup
      @store.transaction {
        report_id = @store.next_id
        report = Report.new(@report_type, report_id)
        report.add_message(@messages[0])
        report.add_message(@messages[1])
        @store.store(report)
      }
      lreport = @store.load(@report_type, report_id)
      assert_equal(2, lreport.size)
      assert_equal(@email[1], lreport.last['email'])
      
      @store.transaction {
        report = Report.new(@report_type, report_id)
        report.add_message(@messages[0])
        assert_equal(1, report.size)
        @store.remake(report)
      }
      lreport = @store.load(@report_type, report_id)
      assert_equal(1, lreport.size)
      assert_equal(@email[0], lreport.last['email'])
    end
    
    def test_capital_project()
      project_id = 'MySQLStoreTestProject'
      
      MySQLStore4.create(nil, project_id, @report_type, @charset)
      store = MySQLStore4.new(nil, project_id, @report_type, @charset)
      sleep(1)
      MySQLStore4.destroy(nil, project_id)
    end
    
    def test_sql_time()
      report_id = nil
      
      report = Report.new(@report_type, report_id)
      report.add_message(@messages[0])
      now = Time.now
      @store.transaction {
        report_id = @store.next_id
        @store.store(report)
      }
      
      row = nil
      @store.execute() do |db|
        row = db.select_one("select create_time from #{@project_id}_messages")
      end
      
      fmt = '%Y-%m-%d %H:%M'
      assert_equal(now.strftime(fmt), row['create_time'].to_time.strftime(fmt))
    end

  end
end
