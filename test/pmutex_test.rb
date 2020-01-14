require 'test/unit'

require 'kagemai/pmutex'

class TestPMutex < Test::Unit::TestCase
  include Kagemai

  def setup
    @filename = 'test/testfile/p_mutex_lock'
    File.open(@filename, 'w') {|file| }
    
    @mutex = PMutex.new(@filename)
    @mutex2 = PMutex.new(@filename)

    @lock = Mutex.new
  end
  
  def teardown
    File.unlink(@filename)
  end
  
  # test use same mutex.
  def test_sync
    r1 = nil
    r2 = nil
    
    count = 1
    
    current = Thread.current
    
    @lock.lock
    t1 = Thread.start {
      @mutex.synchronize {
        @lock.lock
        r1 = count
        count += 1
      }
    }
    
    t2 = Thread.start {
      @mutex.synchronize {
        r2 = count
        count += 1
      }
    }
    @lock.unlock
    
    t1.join
    t2.join
    
    assert_equal(1, r1)
    assert_equal(2, r2)
  end
  
  # test use different mutex.
  def test_sync2
    r1 = nil
    r2 = nil
    
    count = 1
    
    @lock.lock
    t1 = Thread.start {
      @mutex.synchronize {
        @lock.lock
        r1 = count
        count += 1
      }
    }
    
    t2 = Thread.start {
      @mutex2.synchronize {
        r2 = count
        count += 1
      }
    }
    @lock.unlock
    
    t1.join
    t2.join
    
    assert_equal(1, r1)
    assert_equal(2, r2)
  end

  # recursive sync test
  def test_sync3
    @mutex.synchronize {
      @mutex.synchronize {
        assert(true)
      }
    }
  end
  
end
