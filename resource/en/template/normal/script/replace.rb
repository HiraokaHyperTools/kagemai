# Replace rendered for email address masking.

class ReplaceRenderer
  include HtmlRenderer

  def initialize(pattern, replace)
    super(false)
    @pattern = pattern
    @replace = replace
  end

  def do_render(element, value)
    value.gsub(@pattern, @replace)
  end
end

ElementType.add_element_renderer(thread, 'email', ReplaceRenderer.new(/@/, ' at '))
