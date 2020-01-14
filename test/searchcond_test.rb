require 'test/unit/testcase'

require 'kagemai/searchcond'
include Kagemai

class TestSearchInclude < Test::Unit::TestCase
  SQL_SEARCH_OP = {
    true     => 'true',
    false    => 'false',
    'regexp' => '~',
  }
  
  def setup()
    @key = 'attr'
    @message = {
      @key => 'hello kagemai world'
    }
  end

  def test_case_insensitive_re_pattern()
    cond = SearchInclude.new(@key, 'kagemai')

    expect = "[KkＫｋ][AaＡａ][GgＧｇ][EeＥｅ][MmＭｍ][AaＡａ][IiＩｉ]"
    result = cond.case_insensitive_re_pattern('kagemai')
    assert_equal(expect, result)
  end

  def test_case_insensitive_re_pattern2()
    cond = SearchInclude.new(@key, 'ＫagＥmai')
    
    expect = "[KkＫｋ][AaＡａ][GgＧｇ][EeＥｅ][MmＭｍ][AaＡａ][IiＩｉ]"
    result = cond.case_insensitive_re_pattern('Ｋagｅmai')
    assert_equal(expect, result)
  end

  def test_match()
    cond = SearchInclude.new(@key, 'kagemai')
    assert(cond.match(@message))

    cond = SearchInclude.new(@key, 'fukuoka')
    assert(!cond.match(@message))
  end

  def test_match_case_insensitive()
    cond = SearchInclude.new(@key, 'Kagemai', false)
    assert(!cond.match(@message))

    cond = SearchInclude.new(@key, 'KagemaI', true)
    assert(cond.match(@message))
  end

  def test_match_case_insensitive2()
    cond = SearchInclude.new(@key, 'Ｋagｅmai', false)
    assert(!cond.match(@message))

    cond = SearchInclude.new(@key, 'Ｋagｅmai', true)
    assert(cond.match(@message))
  end

  def test_match_case_insensitive3()
    message = {'num' => '0123456789'}
    cond = SearchInclude.new('num', '１2３', false)
    assert(!cond.match(message))
    
    cond = SearchInclude.new('num', '１2３', true)
    assert(cond.match(message))
  end

  def test_match_case_insensitive4()
    message = {'sym' => '！＠＄−［］'}
    cond = SearchInclude.new('sym', '!＠$-[]', false)
    assert(!cond.match(message))
    
    cond = SearchInclude.new('sym', '!＠$-[]', true)
    assert(cond.match(message))
  end

  def test_to_sql()
    cond = SearchInclude.new(@key, 'kagemai')
    assert_equal("#{@key} like '%kagemai%'", cond.to_sql(SQL_SEARCH_OP) {|eid| eid})
  end

  def test_to_sql_case_insensitive()
    cond = SearchInclude.new(@key, 'Ｋagｅmai', true)
    assert_equal("#{@key} ~ '[KkＫｋ][AaＡａ][GgＧｇ][EeＥｅ][MmＭｍ][AaＡａ][IiＩｉ]'", cond.to_sql(SQL_SEARCH_OP) {|eid| eid})
  end
  
end

class TestSearchRegexp < Test::Unit::TestCase
  SQL_SEARCH_OP = {
    true     => 'true',
    false    => 'false',
    'regexp' => '~',
  }

  def test_match()
    message = {
      'attr' => 'hello kagemai world'
    }

    cond1 = SearchRegexp.new('attr', 'hello.*world')
    assert(cond1.match(message))

    cond2 = SearchRegexp.new('attr', 'hello|world')
    assert(cond2.match(message))
  end

  def test_to_sql()
    cond1 = SearchRegexp.new('attr', 'hello.*world')
    assert_equal("attr ~ 'hello.*world'", cond1.to_sql(SQL_SEARCH_OP) {|eid| eid})
    
    cond1 = SearchRegexp.new('attr', "hello' kagemai world")
    assert_equal("attr ~ 'hello\\' kagemai world'", cond1.to_sql(SQL_SEARCH_OP) {|eid| eid})
  end

end

