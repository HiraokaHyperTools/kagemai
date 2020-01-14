require 'test/unit'
require 'kagemai/message'
require 'kagemai/reporttype'
require 'kagemai/elementtype'
require 'kagemai/message_bundle'

require 'kagemai/xmlstore'

include Kagemai

class TestXMLStore < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @dir = 'test/testfile'
    @report_type = ReportType.load('test/testfile/rtype0.xml')

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

    begin
      FileStore.create(@dir, nil, @report_type, 'UTF-8')
      @store = XMLFileStore.new(@dir, nil, @report_type, 'UTF-8')
      @store.disable_cache
    rescue Exception
      FileStore.destroy(@dir, nil)
      raise
    end
  end

  def teardown
    FileStore.destroy(@dir, nil)
  end

  def test_next_id
    assert_equal(1, @store.next_id())
  end

  def test_store()
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
    assert_instance_of(Kagemai::Report, lreport)
    assert_equal(2, lreport.size)
    assert_equal(@email[0], lreport.first['email'])
    assert_equal(@body[0], lreport.first['message'])
    assert_equal(@email[1], lreport.last['email'])
    assert_equal(@body[1], lreport.last['message'])
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
    assert_equal(@email[1], report.last['email'])

    new_email = 'kagemai_test@daifukuya.com'
    report.last['email'] = new_email
    report.last.modified = true
    @store.transaction {
      @store.update(report)
    }

    lreport = @store.load(@report_type, report_id)
    assert_equal(new_email, lreport.last['email'])
  end

  def test_update2()
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
      @store.update(report)
    }
    lreport = @store.load(@report_type, report_id)
    assert_equal(1, lreport.size)
    assert_equal(@email[0], lreport.last['email'])
  end

  def test_hide_message()
    report = nil
    report_id = nil
      
    message = @messages[0].dup
    @store.transaction {
      report_id = @store.next_id
      report = Report.new(@report_type, report_id)
      @messages[1].hide = true
      report.add_message(@messages[0])
      report.add_message(@messages[1])
      @store.store(report)
    }
    
    lreport = @store.load(@report_type, report_id)
    assert_equal(true, lreport.at(2).hide?)
  end

  def test_hide_report()
    report = nil
    report_id = nil
      
    message = @messages[0].dup
    @store.transaction {
      report_id = @store.next_id
      report = Report.new(@report_type, report_id)
      @messages[0].hide = true
      @messages[1].hide = true
      report.add_message(@messages[0])
      report.add_message(@messages[1])
      @store.store(report)
    }
    
    lreport = @store.load(@report_type, report_id)
    assert_equal(true, lreport.hide?)
  end
end
