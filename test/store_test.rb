require 'test/unit'

require 'kagemai/store'

class TestStore < Test::Unit::TestCase
  def setup
    @store = Kagemai::Store.new(nil, nil, nil, 'UTF-8')
  end

  def test_new
    assert_instance_of(Kagemai::Store, @store)
  end

  def test_store
    assert_raise(NotImplementedError) {
      @store.store('report')
    }
  end

  def test_load
    assert_raise(NotImplementedError) {
      @store.load(nil, 'id')
    }
  end

  def test_next_id
    assert_raise(NotImplementedError) {
      @store.next_id()
    }
  end
end
