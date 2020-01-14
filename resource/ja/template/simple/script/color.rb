
class ColorRenderer
  include HtmlRenderer

  def initialize(color_map, index_only = false)
    @color_map = color_map
    super(index_only)
  end

  def do_render(element, value)
    if @color_map.has_key?(value) then
      %Q!<span style="color: #{@color_map[value]}">#{value}</span>!
    else
      value
    end
  end
end

colors = [
  "#4040F0",
  "#4000B0",
  "#004070",
  "#300030",
  "#000030",
  "#000000",
]

status_colors = {}
@project.report_type['status'].each_with_index do |choice, i|
  colors << "#000000" if colors.size > i
  status_colors[choice.id] = colors[i]
end

ElementType.add_element_renderer(thread, 'status', ColorRenderer.new(status_colors, true))
