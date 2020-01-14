require 'test/unit'

require 'kagemai/daterange'
include Kagemai

class TestDateRange < Test::Unit::TestCase
  
  def test_initialize()
    range = DateRange.new('2003/02/01', '2003/07/01')
    assert_equal(DateRange::DateStruct.new(2003, 2, 1), range.start_date)
    assert_equal(DateRange::DateStruct.new(2003, 7, 1), range.end_date)
  end
  
  
  def test_each_month()
    range = DateRange.new('2002/10/01', '2003/03/01')
    
    expect = [[2002, 10], [2002, 11], [2002, 12], [2003, 01], [2003, 02], [2003, 03]]
    result = []
    
    range.each_month() {|year, month| result << [year, month]}
    
    assert_equal(expect, result)
  end
  
  def test_each_day()
    range = DateRange.new('2003/07/01', '2003/07/05')
    
    expect = [[2003, 7, 1], [2003, 7, 2], [2003, 7, 3], [2003, 7, 4], [2003, 7, 5]]
    result = []
    
    range.each_day() {|year, month, day| result << [year, month, day]}
    
    assert_equal(expect, result)
  end
  
end
