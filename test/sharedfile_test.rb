require 'test/unit'

require 'kagemai/sharedfile'

class TestSharedFile < Test::Unit::TestCase
  include Kagemai

  def setup
    @filename = 'test/testfile/sharedfile_test'
    @body = 'hello world'

    SharedFile.write_open(@filename) do |file|
      file.write(@body)
    end
  end

  def teardown
    File.unlink(@filename) if File.exists?(@filename)
    File.unlink(@filename + '~') if File.exists?(@filename + '~')
  end

  def test_multi_read
    r1 = ''
    r2 = ''
    t1 = Thread.new {
      SharedFile.read_open(@filename) {|file|
        r1 = file.read
        sleep(1)
      }
    }
    
    t2 = Thread.new {
      SharedFile.read_open(@filename) {|file|
        r2 = file.read
        sleep(1)
      }
    }

    t1.join
    t2.join

    assert_equal(@body, r1)
    assert_equal(@body, r2)
  end

  def test_read_write
    r1 = ''
    r2 = ''

    o1 = 'hello writing'

    t1 = Thread.new {
      SharedFile.read_open(@filename) {|file|
        sleep(1)
        r1 = file.read
      }
    }

    t2 = Thread.new {
      SharedFile.write_open(@filename) {|file|
        file.write(o1)
        file.flush()
        sleep(1)
      }
    }

    t3 = Thread.new {
      SharedFile.read_open(@filename) {|file|
        sleep(1)
        r2 = file.read
      }
    }


    t1.join
    t2.join
    t3.join

    r3 = ''
    SharedFile.read_open(@filename) {|file|
      r3 = file.read
    }
    
    assert_equal(@body, r1)
    assert_equal(@body, r2)
    assert_equal(o1, r3)
  end
  
end
