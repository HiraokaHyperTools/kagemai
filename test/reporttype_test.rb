require 'test/unit'
require 'kagemai/reporttype'
require 'kagemai/message_bundle'

class String
  def id
    self
  end

  def use_cookie?() false; end
  def use_cache?() false; end
end

class TestReportType < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @rtype = Kagemai::ReportType.new

    @etypes = ['e1', 'e2', 'e3']
    @etypes.each do |e|
      @rtype.add_element_type(e)
    end
  end

  def test_new
    assert_instance_of(Kagemai::ReportType, @rtype)
  end

  def test_each
    result = Array.new
    @rtype.each do |e|
      result.push(e)
    end
    assert_equal(@etypes, result)
  end

  def test_assoc
    assert_equal('e1', @rtype['e1'])
  end

  # EUC の ReportType のロード
  def test_load
    xmlfile = 'test/testfile/rtype0.xml'
    Kagemai::ReportType.module_eval('include Enumerable')
    
    rtype = Kagemai::ReportType.load(xmlfile)
    assert_instance_of(Kagemai::ReportType, rtype)
    
    # 期待する要素の定義
    email = Kagemai::StringElementType.new({'id' => 'email', 'name' => '送信者'})
    email.description = '送信者のメールアドレスを入力してください。'
    status = Kagemai::SelectElementType.new({'id' => 'status', 'name' => '状況', 'default' => '新規'})
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '新規'}))
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '未解決'}))
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '解決済み'}))
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '完了'}))
    message = Kagemai::TextElementType.new({'id' => 'message', 'name' => '内容'})
    message.description = '簡潔・明瞭にどうぞ。余分な引用や挨拶はいりません。'
    cookie = Kagemai::BooleanElementType.new({'id' => 'cookie', 'name' => 'メールアドレスの保存', 'default' => 'true'})
    cookie.description = 'クッキーを使用してメールアドレスを保存する。'
    
    expect_etypes = [email, status, message, cookie]
    etypes = rtype.to_a
    (0..(expect_etypes.size - 1)).each do |i|
      assert_equal(expect_etypes[i], etypes[i])
    end
  end
  
  # UTF-8 の ReportType のロード
  def test_load_utf8
    xmlfile = 'test/testfile/rtype0_utf8.xml'
    Kagemai::ReportType.module_eval('include Enumerable')
    
    rtype = Kagemai::ReportType.load(xmlfile)
    assert_instance_of(Kagemai::ReportType, rtype)
    
    # 期待する要素の定義
    email = Kagemai::StringElementType.new({'id' => 'email', 'name' => '送信者'})
    email.description = '送信者のメールアドレスを入力してください。'
    status = Kagemai::SelectElementType.new({'id' => 'status', 'name' => '状況', 'default' => '新規'})
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '新規'}))
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '未解決'}))
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '解決済み'}))
    status.add_choice(Kagemai::SelectElementType::Choice.new({'id' => '完了'}))
    message = Kagemai::TextElementType.new({'id' => 'message', 'name' => '内容'})
    message.description = '簡潔・明瞭にどうぞ。余分な引用や挨拶はいりません。'
    cookie = Kagemai::BooleanElementType.new({'id' => 'cookie', 'name' => 'メールアドレスの保存', 'default' => 'true'})
    cookie.description = 'クッキーを使用してメールアドレスを保存する。'
    
    expect_etypes = [email, status, message, cookie]
    etypes = rtype.to_a
    (0..(expect_etypes.size - 1)).each do |i|
      assert_equal(expect_etypes[i], etypes[i])
    end
  end
  
end

