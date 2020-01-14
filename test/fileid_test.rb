require 'test/unit'
require 'kagemai/filestore'

class TestSeqFile < Test::Unit::TestCase
  def setup
    @filename = 'test/testfile/id'
    @idfile = Kagemai::SeqFile.open(@filename)
  end

  def teardown
    @idfile.close
    File.unlink(@filename)
  end

  def test_new
    assert_instance_of(Kagemai::SeqFile, @idfile)
  end

  def test_current
    assert_equal(0, @idfile.current)
  end

  def test_next
    assert_equal(1, @idfile.next())
    assert_equal(2, @idfile.next())
    assert_equal(3, @idfile.next())
  end

  def test_next2
    begin
      filename = @filename + '2'
      3.times do |i|
        Kagemai::SeqFile.open(filename) do |idfile|
          assert_equal(i + 1, idfile.next())
        end
      end
    ensure
      File.unlink(filename)
    end
  end

end
