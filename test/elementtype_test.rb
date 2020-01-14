require 'test/unit'
require 'kagemai/elementtype'
require 'kagemai/element'

require 'kagemai/message_bundle'

class TestElementType < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
  end

  def test_new
    id = 'an_element'
    name = 'name of an element'
    etype = Kagemai::ElementType.new({'id' => id, 'name' => name})

    assert_instance_of(Kagemai::ElementType, etype)
    assert_equal(id, etype.id)
    assert_equal(name, etype.name)
    assert_nil(etype.default)
    assert_equal('', etype.description)
  end

  def test_new2
    id = 'an_element'
    name = 'name of an element'
    default = 'hoge'
    description = 'desc'
    etype = Kagemai::ElementType.new({'id' => id, 
                                       'name' => name, 
                                       'default' => default, 
                                       'description' => description})

    assert_instance_of(Kagemai::ElementType, etype)
    assert_equal(id, etype.id)
    assert_equal(name, etype.name)
    assert_equal(default, etype.default)
    assert_equal(description, etype.description)
  end

  def test_add_attr
    id = 'an_element'
    name = 'name of an element'
    etype = Kagemai::ElementType.new({'id' => id, 'name' => name})
    
    etype.add_attr('a1', 'v1', true)
    etype.add_attr('a2', 'v2', true)

    assert(etype.respond_to?('a1'))
    assert(etype.respond_to?('a2'))
    assert(etype.respond_to?('a1='))
    assert(etype.respond_to?('a2='))

    assert_equal('v1', etype.a1) 
    assert_equal('v2', etype.a2) 

    etype.a1 = 'value1'
    etype.a2 = 'value2'

    assert_equal('value1', etype.a1) 
    assert_equal('value2', etype.a2) 
  end

  def test_equals
    attr = {
      'id' => 'e', 
      'name' => 'n',
      'default' => 'd',
      'description' => 'dec'
    }
    e1 = Kagemai::ElementType.new(attr)
    e2 = Kagemai::ElementType.new(attr)
    assert(e1 == e2)
  end
end

class TestStringElementType < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
  end

  def test_new
    etype = Kagemai::StringElementType.new({'id' => 's', 'name' => 'sname'})
    assert_equal('s', etype.id)
  end
end

class TestSelectElementType < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @etype = Kagemai::SelectElementType.new({'id' => 's', 'name' => 'sname'})
  end

  def test_new
    assert_equal('s', @etype.id)
  end

  def test_add_choice
    choices = ['c1', 'c2']
    choices.each do |c|
      @etype.add_choice(Kagemai::SelectElementType::Choice.new({'id' => c}))
    end

    result = Array.new
    @etype.each do |c|
      result.push(c.id)
    end

    assert_equal(choices, result)
  end

  def test_equals
    etype2 = Kagemai::SelectElementType.new({'id' => 's', 'name' => 'sname'})
    etype3 = Kagemai::SelectElementType.new({'id' => 's', 'name' => 'sname'})
    choices = ['c1', 'c2']
    choices.each do |c|
      @etype.add_choice(Kagemai::SelectElementType::Choice.new({'id' => c}))
      etype2.add_choice(Kagemai::SelectElementType::Choice.new({'id' => c}))
    end
    etype3.add_choice(Kagemai::SelectElementType::Choice.new({'id' => 'c1'}))

    assert(@etype == etype2)
    assert(@etype != etype3)
  end
end

class TestChoice < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
  end
  
  def test_marshal
    expect = Kagemai::SelectElementType::Choice.new({'id' => 'c1'})
    s = expect._dump(-1)
    output = Kagemai::SelectElementType::Choice._load(s)
    assert_equal(expect, output)
  end
end

class TestMultiSelectElementType < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
    @etype = Kagemai::MultiSelectElementType.new({'id' => 's', 'name' => 'sname'})
    
    @choices = ['c1', 'c2']
    @choices.each do |c|
      @etype.add_choice(Kagemai::SelectElementType::Choice.new({'id' => c}))
    end
  end
  
  def test_marshal
    s = @etype._dump(-1)
    etype = Kagemai::MultiSelectElementType._load(s)
    expect = @etype.collect {|c| c}
    output = etype.collect {|c| c}
    assert_equal(expect, output)
    assert_equal(@etype, etype)
  end
end


class TestTextElementType < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
  end

  def test_new
    etype = Kagemai::TextElementType.new({'id' => 's', 'name' => 'sname'})
    assert_equal('s', etype.id)
  end
end

class TestBooleanElementType < Test::Unit::TestCase
  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)
  end

  def test_new
    etype = Kagemai::BooleanElementType.new({'id' => 's', 'name' => 'sname'})
    assert_equal('s', etype.id)
  end
end

module Kagemai
  class FileElementType < ElementType
    class FileInfo
      def ==(rhs)
        @seq == rhs.seq &&
          @name == rhs.name &&
          @size == rhs.size &&
          @mime_type == rhs.mime_type &&
          @create_time == rhs.create_time &&
          @comment == rhs.comment &&
          @discarded == rhs.discarded
      end
    end
  end
end

class TestFileElementType < Test::Unit::TestCase
  include Kagemai

  def setup
    Kagemai::MessageBundle.open('resource', 'ja', 'messages', false)

    @a1 = FileElementType::FileInfo.new(1, 'hoge', 20, 'text/plain', 'c1', Time.at(1))
    @a2 = FileElementType::FileInfo.new(1, 'hoge,hagu', 20, 'text/plain', 'c2', Time.at(1), true)
    @a3 = FileElementType::FileInfo.new(1, 'hoge\hagu', 20, 'text/plain', 'c3', Time.at(1))

    @etype = FileElementType.new('id' => 'attachment', 'name' => 'attchment')
    @elem = Element.new(@etype, nil)
  end
  
  def test_attachment_to_s
    assert_equal('1,hoge,20,text/plain,c1,1,false', @a1.to_s)
    assert_equal('1,hoge\,hagu,20,text/plain,c2,1,true', @a2.to_s)
    assert_equal('1,hagu,20,text/plain,c3,1,false', @a3.to_s)
  end

  def test_attachment_parse
    assert_equal(@a1, 
                  FileElementType::FileInfo.parse('1,hoge,20,text/plain,c1,1,false'))
    assert_equal(@a2, 
                  FileElementType::FileInfo.parse('1,hoge\,hagu,20,text/plain,c2,1,true'))
    assert_equal(@a3, 
                  FileElementType::FileInfo.parse('1,hoge\\hagu,20,text/plain,c3,1,false'))
  end

  def test_get_value
    @elem.add_fileinfo(FileElementType::FileInfo.new(1, 'hoge', 20, 'text/plain', 'c1', Time.at(1)))
    assert_equal('1,hoge,20,text/plain,c1,1,false', @elem.value)
  end

  def test_get_value2
    @elem.add_fileinfo(FileElementType::FileInfo.new(1, 'hoge;hagu', 20, 'text/plain', 'c1', Time.at(1)))
    assert_equal('1,hoge\;hagu,20,text/plain,c1,1,false', @elem.value)
  end
  
  def test_set_value
    @elem.add_fileinfo(FileElementType::FileInfo.new(1, 'hoge', 20, 'text/plain', 'c1', Time.at(1)))
    @elem.add_fileinfo(FileElementType::FileInfo.new(2, 'hoge;hagu', 20, 'text/plain', 'c2', Time.at(2)))
    str = @elem.value
    
    @elem.value = str
    assert_equal(str, @elem.value)
  end

  

end
