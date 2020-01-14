require 'test/unit'

require 'fileutils'
require 'kagemai/bts'

class TestBTS < Test::Unit::TestCase
  class DummyApp
    def initialize
      @lang = 'ja'
    end
    attr_reader :lang
  end

  def setup()
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @base_dir = 'test/testfile/projects'
    @bts = Kagemai::BTS.new(@base_dir)

    @default_store = Kagemai::BTS::DEFAULT_DB_MANAGER_CLASS
  end

  def teardown()
  end

  def test_open_project()
    project = @bts.open_project('p1')
    assert_instance_of(Kagemai::Project, project)
  end

  def test_each_project()
    expect = ['p1', 'p2']
    result = []
    Thread.current[:CGIApplication] = DummyApp.new
    @bts.each_project do |project|
      result.push(project.id)
    end
    assert_equal(expect, result)
  end

  def test_exist_project?()
    assert_equal(true, @bts.exist_project?('p1'))
    assert_equal(false, @bts.exist_project?('p3'))
  end
  
  def test_convert_store1()
    return unless Kagemai::Config[:enable_mysql]
    
    id = '_filestore_test'
    expect_id = '_filestore_expect'
    id_path = "#{@base_dir}/#{id}"
    expect_path = "#{@base_dir}/#{expect_id}"
    begin
      copy_store(expect_path, id_path)
      
      store = Kagemai::FileStore
      project = @bts.open_project(id)
      
      conv_store = Kagemai::MySQLStore4
      
      @bts.convert_store(id, project.charset, project.report_type, store, conv_store)
      sleep(1)
      @bts.convert_store(id, project.charset, project.report_type, conv_store, store)
      sleep(1)
      
      result = []
      expect = []
      @bts.open_project(id).each{|r| result << r}
      @bts.open_project(expect_id).each{|r| expect << r}
      assert_equal(expect.size, result.size)
      
      result.each_with_index do |r, i|
        assert_report(expect[i], r)
      end
    ensure
      system("rm -rf #{id_path}")
    end
  end

  private
  
  def copy_store(src, dest)
    list = []
    Dir.glob(src + '/**/*') do |path|
      next if path.include?('.svn')
      next if path[0] == '.'
      list << path.untaint
    end
    
    FileUtils.mkdir(dest) unless File.exist?(dest)
    list.sort_by{|path| path.size}.each do |path|
      if File.directory?(path) then
        FileUtils.mkdir(dest + path[src.size..-1])
        next
      end
      FileUtils.copy(path, dest + path[src.size..-1])
    end
  end
  
  def assert_report(expect, result)
    expect.each_with_index do |em, i|
      rm = result.at(i + 1)
      em.each do |etype, etype_id, etype_name, value|
        assert_equal(value, rm[etype_id])
      end
    end
  end

end

