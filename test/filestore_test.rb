require 'test/unit'

require 'kagemai/filestore'
require 'kagemai/reporttype'
require 'kagemai/message_bundle'
require 'kagemai/searchcond'

require 'fileutils'
require 'test/simple_message'

class SimpleMessageWriter
  def write(port, message)
    port << message.value.to_s
  end
end

class SimpleMessageReader
  def read(port, report_type, id)
    SimpleMessage.new(id, port.read)
  end
end

class TestFileStore < Test::Unit::TestCase
  include Kagemai

  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @dir = 'test/testfile'
    @report_type = ReportType.load('test/testfile/rtype0.xml')

    begin
      FileStore.create(@dir, nil, @report_type, 'UTF-8')
      @fs = FileStore.new(@dir, nil, @report_type, 'UTF-8')
      @fs.disable_cache
    rescue Exception
      FileStore.destroy(@dir, nil)
      raise
    end
  end

  def teardown
    FileStore.destroy(@dir, nil)
  end
  
  def test_next_id
    assert_equal(1, @fs.next_id())
  end

  def test_store
    @fs.set_message_writer(SimpleMessageWriter.new())

    report_id = 1
    message_id = 1
    value = 'hello'
    value2 = 'world'

    report = Report.new(@report_type, report_id)
    report.add_message(SimpleMessage.new(message_id, value))
    report.add_message(SimpleMessage.new(message_id + 1, value2))
    @fs.store(report)

    result = nil
    File.open("#{@dir}/#{FileStore::SPOOL_NAME}/#{report_id}/#{message_id}") do |file|
      result = file.read
    end
    assert_equal(value, result)

    File.open("#{@dir}/#{FileStore::SPOOL_NAME}/#{report_id}/#{message_id + 1}") do |file|
      result = file.read
    end
    assert_equal(value2, result)
  end

  def test_load()
    report_id = 1
    value = 'hello'
    value2 = 'world'

    report_path = "#{@dir}/#{FileStore::SPOOL_NAME}/#{report_id}"
    Dir.mkdir(report_path)
    File.open("#{report_path}/1", 'w') {|file| file << value}
    File.open("#{report_path}/2", 'w') {|file| file << value2}
      
    @fs.set_message_reader(SimpleMessageReader.new)
    report = @fs.load(@report_type, report_id)
    
    assert_instance_of(Report, report)
    assert_equal(2, report.size)

    assert_equal(1, report.at(1).id)
    assert_equal(value, report.at(1).value)

    assert_equal(2, report.at(2).id)
    assert_equal(value2, report.at(2).value)
  end

  def test_xml_store()
    message = Message.new(@report_type, 1)
    message['email'] = 'fukuoka@daifukuya.com'
    message['status'] = '新規'
    message['message'] = 'hello world!'
    message['cookie'] = 'true'
    message.time = Time.at(0)

    message.set_option('opt1', 'opt_v1')
    message.set_option('opt2', true)
    message.set_option('opt3', false)
    
    report = Report.new(@report_type, @fs.next_id)
    report.add_message(message)

    @fs.store(report)
    assert_equal(1, @fs.size)

    result = nil
    File.open("#{@dir}/#{FileStore::SPOOL_NAME}/1/1", 'rb') do |file|
      result = file.read
    end

    expect = nil
    File.open('test/testfile/xmlspool/expect0.xml', 'rb') do |file|
      expect = file.read.gsub(/\r/, '')
    end

    assert(!expect.nil?)
    assert_equal(expect, result)
  end

  def test_xml_load()
    report_id = 1
    
    report_path = "#{@dir}/#{FileStore::SPOOL_NAME}/#{report_id}"
    Dir.mkdir(report_path)
    FileUtils.copy('test/testfile/xmlspool/expect0.xml', "#{report_path}/1")
    
    report = @fs.load(@report_type, report_id)
    assert_instance_of(Report, report)
    assert_equal(1, report.size)

    message = report.last()
    assert_instance_of(Message, message)
    assert_equal('fukuoka@daifukuya.com', message['email'])
    assert_equal('新規', message['status'])
    assert_equal('hello world!', message['message'])
    assert_equal('true', message['cookie'])

    options = {
      'opt1' => 'opt_v1',
      'opt2' => true,
      'opt3' => false,
    }

    opt_result = {}
    message.each_option do |name, value|
      opt_result[name] = value
    end
    assert_equal(options, opt_result)
  end

  def test_xml_load2() # test load broken xml file
    report_id = 1
    
    report_path = "#{@dir}/#{FileStore::SPOOL_NAME}/#{report_id}"
    Dir.mkdir(report_path)
    FileUtils.copy('test/testfile/xmlspool/broken0.xml', "#{report_path}/1")
    FileUtils.copy('test/testfile/xmlspool/broken1.xml', "#{report_path}/2")
    
    assert_raise(Kagemai::RepositoryError) {
      report = @fs.load(@report_type, report_id)
    }
  end

  def test_search()
    message1 = Message.new(@report_type, 1)
    message1['email'] = 'fukuoka@daifukuya.com'
    message1['status'] = '新規'
    message1['message'] = 'hello world!'
    message1['cookie'] = 'true'
    message1.time = Time.at(0)

    message2 = Message.new(@report_type, 2)
    message2['email'] = 'fukuoka@daifukuya.com'
    message2['status'] = '保留'
    message2['message'] = 'hello world!'
    message2['cookie'] = 'true'
    message2.time = Time.at(0)

    report = Report.new(@report_type, @fs.next_id)
    report.add_message(message1)
    report.add_message(message2)
    @fs.store(report)

    message1.modified = true

    report = Report.new(@report_type, @fs.next_id)
    report.add_message(message1)
    @fs.store(report)

    assert_equal(2, @fs.size)

    cond = SearchEqual.new('status', '新規')

    result = @fs.search(@report_type, 
                        cond, 
                        NullSearchCond.new(true),
                        true, 50, 0, 'report_id')

    assert_equal(1, result.reports.size)
  end

  def test_search2()
    message1 = Message.new(@report_type, 1)
    message1['email'] = 'fukuoka@daifukuya.com'
    message1['status'] = '新規'
    message1['message'] = 'hello world!'
    message1['cookie'] = 'true'
    message1.time = Time.at(0)

    message2 = Message.new(@report_type, 2)
    message2['email'] = 'fukuoka@daifukuya.com'
    message2['status'] = '保留'
    message2['message'] = 'hello world!'
    message2['cookie'] = 'true'
    message2.time = Time.at(0)

    report = Report.new(@report_type, @fs.next_id)
    report.add_message(message1)
    report.add_message(message2)
    @fs.store(report)

    message1.modified = true

    report = Report.new(@report_type, @fs.next_id)
    report.add_message(message1)
    @fs.store(report)

    assert_equal(2, @fs.size)

    cond = SearchEqual.new('status', '新規')
    cond2 = SearchEqual.new('email', 'fukuoka@daifukuya.com')

    result = @fs.search(@report_type, cond, cond2, true, 50, 0, 'report_id')

    assert_equal(1, result.reports.size)
  end

  def test_search3()
    message1 = Message.new(@report_type, 1)
    message1['email'] = 'fukuoka@daifukuya.com'
    message1['status'] = '新規'
    message1['message'] = 'hello world!'
    message1['cookie'] = 'true'
    message1.time = Time.at(0)

    message2 = Message.new(@report_type, 2)
    message2['email'] = 'fukuoka@daifukuya.com'
    message2['status'] = '保留'
    message2['message'] = 'hello world!'
    message2['cookie'] = 'true'
    message2.time = Time.at(0)

    report = Report.new(@report_type, @fs.next_id)
    report.add_message(message1)
    report.add_message(message2)
    @fs.store(report)

    message1.modified = true

    report = Report.new(@report_type, @fs.next_id)
    report.add_message(message1)
    @fs.store(report)

    assert_equal(2, @fs.size)

    cond = SearchEqual.new('status', '新規')
    cond2 = SearchEqual.new('email', 'fukuoka@daifukuya.com')

    result = @fs.search(@report_type, cond, cond2, false, 50, 0, 'report_id')

    assert_equal(2, result.reports.size)
  end
  
end
