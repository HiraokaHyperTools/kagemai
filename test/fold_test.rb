require 'test/unit'
require 'kagemai/fold'

class TestFold < Test::Unit::TestCase
  include Kagemai
  
  def test_fold_ascii
    #         1234567890123456789012345
    input  = 'this is a long long line.'
    expect = "this is a \nlong long \nline."
    assert_equal(expect, Fold::fold_line(input, 12))
  end
  
  def test_fold_ascii2
    #         1234567890123456789012345
    input  = 'this is a long-long line.'
    expect = "this is a long-\nlong line."
    assert_equal(expect, Fold::fold_line(input, 16))
  end
  
  def test_fold_jp
    input  = 'きょうはいい天気です。'
    expect = "きょうはいい\n天気です。"
    assert_equal(expect, Fold::fold_line(input, 12))
  end
  
  # 行頭禁則
  def test_fold_jp2
    input  = '今日はいいね。'
    expect = "今日はいい\nね。"
    assert_equal(expect, Fold::fold_line(input, 12))
  end
  
  # 行末禁則
  def test_fold_jp3
    input  = '今日はいい（天気）'
    expect = "今日はいい\n（天気）"
    assert_equal(expect, Fold::fold_line(input, 12))
  end
  
  # マルチバイトの中間が折り返し位置になるケース
  def test_fold_jp4
    input2  = 'きょうはいい天気です。'
    expect2 = "きょうはいい\n天気です。"
    assert_equal(expect2, Fold::fold_line(input2, 12))
  end
  
  # 行頭禁則2
  def test_fold_jp5
    input  = 'a今日はいいね。'
    expect = "a今日はいい\nね。"
    assert_equal(expect, Fold::fold_line(input, 12))
  end
  
  # 行末禁則2
  def test_fold_jp6
    input  = 'a今日はいい（天気）'
    expect = "a今日はいい\n（天気）"
    assert_equal(expect, Fold::fold_line(input, 12))
  end
  
  def test_fold_lines
    input = <<INPUT
this is a long long line.
今日はとってもいい天気ですね。
INPUT
    
    expect = <<EXPECT
this is a long 
long line.
今日はとってもい
い天気ですね。
EXPECT
    
    assert_equal(expect, Fold::fold(input, 16))
  end
end
