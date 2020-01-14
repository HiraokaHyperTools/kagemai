=begin
  Renderer - HTML rendering module
=end

module Kagemai

  module HtmlRenderer
    def initialize(index_only = false)
      @index_only = index_only
    end

    def render(element, value)
      result = value

      renderers().each do|renderer|
        result = renderer.do_render(element, result)
      end

      temporal().each do |renderer|
        result = renderer.do_render(element, result)
      end

      result
    end

    def add_renderer(renderer)
      renderers() << renderer
    end

    def add_renderer_front(renderer)
      renderers().unshift(renderer)
    end

    def remove_renderer(renderer)
      renderers().delete_if {|x| x.equal?(renderer)}
    end

    def add_temporal_renderer(renderer)
      temporal() << renderer
    end

    def remove_temporal_renderers()
      @temporal = []
    end

    def do_render(element, value)
      value
    end

    def index_only?()
      @index_only
    end

    private
    def renderers()
      @renderers ||= [self]
      @renderers
    end

    def temporal()
      @temporal ||= []
      @temporal
    end
  end

  class BtsLinkRenderer
    include HtmlRenderer
    
    def initialize(use_host = false)
      @use_host = use_host
    end
    
    def do_render(element, value)
      mode = CGIApplication.instance.mode
      value.gsub(/&lt;(BTS|bts)(?::(#{Project::ID_REGEXP_STR}))?:(\d+)&gt;/m) {
        p_str = ''
        if $2 then
          project_id = $2
          report_id = $3
          p_str = ":#{project_id}"
        else
          project_id = Project.instance.id
          report_id = $3
        end
        param = {
          'action'  => ViewReport.name,
          'project' => project_id,
          'id'      => report_id
        }
        
        base_url = @use_host ? "#{Config[:base_url]}#{mode.url}" : mode.url
        "&lt;#{$1}#{p_str}:#{report_id}&gt;".href(base_url, param)
      }
    end
  end

  class UrlRenderer
    include HtmlRenderer

    module HttpUrl 
      # RFC 2396, 2616, RubyMagic pp.75-85
      # NOTE: escape_h された文字列を対象にするため、'&' を '&amp;' にしている。
      #       実用上 '(' と ')' は含めない方が良さそうなので削除している (BTS:86)
      alpha         = '[A-Za-z]'
      alphanum      = '[\w]'
      alphanum2     = '[\w\-]'
      escaped       = '%[0-9A-Fa-f]{2}'
      reserved      = '(?:[;/?:@=+$,]|&amp;)' # s/&/&amp;/
      unreserved    = '[\w\-_.!~*\']'
      uric          = "(?:#{reserved}|#{unreserved}|#{escaped})"
      query         = "#{uric}*"
      pchar         = "(?:#{unreserved}|#{escaped}|[:@=+$,]|&amp;)" # s/&/&amp;/
      param         = "#{pchar}*"
      segment       = "#{pchar}*(?:;#{param})*"
      path_segments = "#{segment}(?:/#{segment})*"
      abs_path      = "/#{path_segments}"
      port          = '\d*'
      ipv4address   = '\d+\.\d+\.\d+.\d+'
      toplabel      = "#{alpha}(?:#{alphanum2}*#{alphanum})?"
      domainlabel   = "#{alphanum}(?:#{alphanum2}*#{alphanum})?"
      hostname      = "(?:#{domainlabel}\\.)*#{toplabel}\\.?"
      host          = "(?:#{hostname}|#{ipv4address})"
      
      fragment      = "#{uric}*"
      scheme        = "(?:http|https|ftp)"
      
      REGEXP_STR  = "#{scheme}://#{host}(?::#{port})?(?:#{abs_path}(?:\\?#{query})?)?(?:##{fragment})?"
      REGEXP      = Regexp.new(REGEXP_STR)
      REGEXP_LINE = Regexp.new('^' + REGEXP_STR + '$')
    end

    def do_render(element, value)
      value.gsub(/(#{HttpUrl::REGEXP_STR})/m, '\1'.href('\1'))
    end
  end

  require 'kagemai/fold'
  class Folding
    include HtmlRenderer
    
    def initialize(column = nil)
      if column then
        @column = column
      else
        @column = Project.instance.fold_column
      end
    end
    
    def do_render(element, value)
      preserved = []
      lines = value.gsub(/<a.*?>.*?<\/a>/im) {
        preserved << $~
        "\001"
      }
      
      result = lines.collect {|line| 
        (/^([>+\-=!\s]|RCS file:|&gt;)/ =~ line) ? line : Fold::fold_line(line, @column)
      }.join('')
      
      result.gsub(/\001/m) {
        preserved.shift
      }
    end
  end

end
