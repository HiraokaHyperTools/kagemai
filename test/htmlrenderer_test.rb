require 'test/unit'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/htmlrenderer'

class TestUrlRenderer < Test::Unit::TestCase
  include Kagemai

  def setup
    @render = UrlRenderer.new
    @url1 = 'http://www.daifukuya.com/'
    @url2 = 'https://www.daifukuya.com/'
    @url3 = 'http://www.daifukuya.com/hoge-1.0.0-2000.data'

    @re = UrlRenderer::HttpUrl::REGEXP
  end

  def test_render
    expect = %Q!<a href="#{@url1}">#{@url1}</a>!
    assert_equal(expect, @render.do_render(nil, @url1))
  end

  def test_render2
    expect = %Q!<a href="#{@url2}">#{@url2}</a>!
    assert_equal(expect, @render.do_render(nil, @url2))
  end

  def test_render3
    expect = %Q!<a href="#{@url3}">#{@url3}</a>!
    assert_equal(expect, @render.do_render(nil, @url3))
  end

  def test_regex
    url = 'http://www.daifukuya.com/'
    m = @re.match(url)
    assert_equal(url, m[0])
  end

  def test_regex2
    url = 'http://www.daifukuya.com/>'
    m = @re.match(url)
    assert(!(url == m[0]))
  end
end


class TestFolding < Test::Unit::TestCase
  include Kagemai

  def test_fold_ascii
    #         1234567890123456789012345
    input  = 'this is a long long line.'
    expect = "this is a \nlong long \nline."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_jp
    #         123456789 123456789 123456789 123456789 123456789
    input  = 'ながいながい文字列をいれて試してみるテストなのですよこれは。'
    expect = "ながいながい文字列を\nいれて試してみるテス\nトなのですよこれは。"
    assert_equal(expect, Folding.new(20).render(nil, input))
  end

  def test_fold_jp2
    #         123456789 123456789 123456789 123456789 123456789
    input  = '> ながいながい文字列をいれてみるとどうなるかためしてみる。'
    expect = '> ながいながい文字列をいれてみるとどうなるかためしてみる。'
    assert_equal(expect, Folding.new(20).render(nil, input))
  end

  def test_fold_with_anchor
    input  = 'hello <a href="http://www.daifukuya.com/archive/kagemai-0.8.0.tar.gz">archive</a>'
    expect = 'hello <a href="http://www.daifukuya.com/archive/kagemai-0.8.0.tar.gz">archive</a>'
    assert_equal(expect, Folding.new(20).render(nil, input))
    assert_equal(expect, Folding.new(70).render(nil, input))
  end

  def test_fold_quote
    input  = '> this is a long long line.'
    expect = "> this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_quote2
    input  = ' this is a long long line.'
    expect = " this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_quote3
    input  = '  this is a long long line.'
    expect = "  this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_quote4
    input  = '+ this is a long long line.'
    expect = "+ this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_quote5
    input  = '- this is a long long line.'
    expect = "- this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_quote6
    input  = '! this is a long long line.'
    expect = "! this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_quote7
    input  = '= this is a long long line.'
    expect = "= this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end

  def test_fold_quote8
    input  = 'RCS file: this is a long long line.'
    expect = "RCS file: this is a long long line."
    assert_equal(expect, Folding.new(12).render(nil, input))
  end


end
