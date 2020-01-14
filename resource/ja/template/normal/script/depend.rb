# Rendering bug dependency.

class DependRenderer
  include HtmlRenderer
  def do_render(element, value)
    mode = CGIApplication.instance.mode
    project = Project.instance

    bugs = value.scan(/\d+/)

    if bugs.size == 0 then
      '¤Ê¤·'
    else
      bugs.collect {|report_id|
        param = {
          'action'  => ViewReport.name,
          'project' => project.id,
          'id'      => report_id
        }
        "#{report_id}".href(mode.url, param)
      }.join(', ')
    end
  end
end

ElementType.add_element_renderer(thread, 'depend', DependRenderer.new)
