require 'test/unit'

require 'kagemai/elementtype'
require 'kagemai/element'
require 'kagemai/cgi/attachment_handler'

class DummyProject
  def store_attachment(attachment, fileinfo)
    attachment.seq_id
  end
end

class DummyAttachment
  def initialize(seq_id, original_filename)
    @seq_id = seq_id
    @original_filename = original_filename
  end
  attr_reader :seq_id, :original_filename

  def stat()
    self
  end

  def size()
    1
  end

  def ctime()
    Time.now
  end
  
  def close()
  end
  
  def to_s()
    "#{@seq_id};#{@original_filename}"
  end
end

class TestAttachmentHandler < Test::Unit::TestCase
  include Kagemai
  include Kagemai::AttachmentHandler

  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)

    @project = DummyProject.new
    @a1 = DummyAttachment.new(1, 'hello.rb')
    @a2 = DummyAttachment.new(2, 'world.rb')
    @a3 = DummyAttachment.new(3, 'hoge.rb')
    @a4 = DummyAttachment.new(4, 'hagu.rb')

    @attachment1 = Kagemai::Attachment.new(@a1, FileElementType::FileInfo.new2(@a1, 'text/plain'))
    
    @fetype = FileElementType.new('id' => 'attachments', 'name' => 'attached')
    @felement = Element.new(@fetype, nil)

    @result = {'file' => @felement}
    def @result.element(k)
      self[k]
    end
  end

  def teardown
  end

  def test_store_attachment
    store_attachments(@project, @result, {'file' => @attachment1})
    assert_equal(@a1.original_filename, @felement.find_fileinfo(1).name)
  end
  
end
