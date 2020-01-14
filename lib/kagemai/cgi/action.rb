=begin
  action.rb - base functions for CGI action
=end

require 'cgi'
require 'kagemai/util'
require 'kagemai/bts'
require 'kagemai/logger'
require 'kagemai/cgi/htmlrenderer'
require 'kagemai/cgi/htmlhelper'

module Kagemai
  class Action
    def self.default?
      return false;
    end
    
    @@actions        = nil
    @@default_action = nil
    @@load_mutex     = Mutex.new
    
    def self.load(dir)
      @@load_mutex.synchronize {
        unless @@actions then
          @@actions = Hash.new
          
          # load actions
          Dir.glob(dir + "/*\.rb").each do |action_script|
            require action_script.untaint
          end
        end
        raise InitializeError, 'No default action loaded.' unless @@default_action
        
        [@@actions, @@default_action]
      }
    end
        
    def self.add_action(action_class)
      @@actions[action_class.name] = action_class
      if action_class.default? then
        @@default_action = action_class
      end
    end
    
    def self.set_default_action(action_class)
      @@default_action = action_class
    end
        
    def initialize(cgi, bts, mode, lang)
      @cgi = cgi
      @bts = bts
      @mode = mode
      @lang = lang
      @charset = @cgi.get_param('charset', Config[:charset])
      @css_url  = Config[:css_url]
      
      @project = nil
      @template_dir = nil
    end
    attr_reader :project
    
    def execute()
      # TODO: override
      raise NotImplementedError, "at #{self.class}"
    end
    
    def cache_key()
      # TODO: override
      self.class.name
    end
    
    def cache_type()
      'none'
    end
    
    def init_project(use_session = false)
      project_id = @cgi.get_param('project', '')
      raise ParameterError, 'project name not specified.' if project_id.empty?
      @project = @bts.open_project(Util.untaint_path(project_id))
      @lang = @project.lang
      @charset = @project.charset
      @template_dir = @project.template_dir()
      @css_url = @project.css_url
      
      @use_cookie = !@cgi.cookies.empty?      
      @email_notification = false
      if @use_cookie then
        cid = @project.id.escape_u + '_email_notification'
        @email_notification = @cgi.cookies[cid][0] == 'true'
      end
      
      @session = nil
      if use_session then
        @session = @cgi.create_session()
      end
      
      # load project script
      script_dir = "#{@project.dir}/#{@project.id}/script"
      Logger.debug("Script", "script dir = : #{script_dir}")
      scripts = []
      Dir.glob("#{script_dir}/*.rb") do |name|
        src = File.open(name.untaint) {|file| file.read}
        scripts << [name, src.untaint]
      end
      
      thread = Thread.current
      Util.safe(1) { # TODO: safe(4) でも動作するように
        scripts.each do |script|
          name, src = script
          eval(src, binding, name) 
        end
      }
    end
        
    def header()
      navi()
    end
    
    def navi()
      eval_template('navi.rhtml', {:project => @project, :cgi => @cgi})
    end
    
    def footer()
      eval_template('footer.rhtml', {:cgi => @cgi})
    end
    
    def cookie_allowed?
      @cgi.get_param('allow_cookie', 'off') == 'on'
    end
    
    def email_notification_allowed?
      @cgi.get_param('email_notification', 'off') == 'on'
    end
    
    def handle_cookies()
      cookie_action = nil
      if cookie_allowed? then 
        cookie_action = :add_cookie
      elsif @use_cookie then
        cookie_action = :delete_cookie
      end
      
      if cookie_action then
        @project.report_type.each do |etype|
          if etype.use_cookie? then
            param = @cgi.get_param(etype.id)
            @cgi.send(cookie_action, etype.cookie_id, param)
          end
        end
        
        @cgi.send(cookie_action, 
                  @project.id.escape_u + '_email_notification', 
                  email_notification_allowed?.to_s)
      end
    end
    
    class TemplateParam
      def initialize(cgi, template_dir, lang, params = {})
        @cgi = cgi
        @template_dir = template_dir
        @lang = lang
        @params = params
      end
      
      def method_missing(name, *args)
        if @params.has_key?(name) then
          return @params[name]
        end
        super
      end
      
      def eval_template(filename, p)
        TemplateParam.new(@cgi, @template_dir, @lang, p).instance_eval {
          Util.eval_template(filename, @template_dir, @lang, binding)
        }
      end
    end
    
    def eval_template(filename, p = {})
      TemplateParam.new(@cgi, @template_dir, @lang, p).instance_eval {
        Util.eval_template(filename, @template_dir, @lang, binding)
      }
    end
  end
  
  class RawActionResult
    def initialize(header, body)
      @header = header
      @body   = body
    end
    
    def respond(cgi, flush_log, show_env, io = $stdout)
      io.print @header
      io.print @body
    end
  end
  
  class ActionResult
    def initialize(title, header, body, footer, css, lang, charset)
      @title = title
      @header = header
      @body = body
      @footer = footer
      @css = css
      @lang = lang
      @charset = charset
    end
            
    def respond(cgi, flush_log, show_env)
      body = http_body(cgi, flush_log, show_env)

      print http_header(cgi, body.size)
      print body
    end
    
    def http_header(cgi, length)
      if defined?(MOD_RUBY) then
        Apache::request.headers_out.clear
      end
      
      opts = {
        'status'   => 'OK',
        'type'     => 'text/html',
        'charset'  => Config[:charset],
        'language' => @lang,
	'length'   => length
      }
      
      cgi.header(opts).gsub(/\n/, "\r\n")
    end
    
    def http_body(cgi, flush_log, show_env)
      log = ''
      if flush_log
        log = "<hr />\n"
        log += "DEBUG Log: <br />\n"
        log += "<pre>" + Logger.buffer().escape_h + "</pre>\n"
        Logger.clear()
      end
      
      env = ''
      if show_env
        env = "<hr />\n"
        env += "Environment Variables: <br />\n"
        env += "<table>"
        env += "<tr><th>name</th><th>value</th></tr>"
        
        ENV.each do |name, value|
          env += "<tr><td>#{name}</td><td>#{value.escape_h}</td></tr>"
        end
        
        env += "</table>"
      end
      
      css_param = {
        'href' => "#{@css}", 
        'type' => 'text/css', 
        'rel' => 'stylesheet'
      }
      css_link = @css.to_s.empty? ? '' : cgi.link(css_param)
      
      head = cgi.head {
        "\n" + 
        cgi.meta({'http-equiv' => 'content-type', 
                  'content' => "text/html; charset=#{@charset}"}) + "\n" +
        cgi.meta({'http-equiv' => 'content-style-type', 
                  'content' => "text/css"}) + "\n" +
        css_link + "\n" +
        cgi.title{@title.escape_h} + "\n"
      }
      
      body = cgi.body {
        "<h1>#{@title.escape_h}</h1>" + 
          @header + "\n" +
          @body + "\n" +
          @footer + log + env
      }
      
      html = cgi.html({'lang' => "#{@lang}"}) { "\n" + head + "\n" + body + "\n" }
      html = html.gsub(/\n/, "\r\n") + "\r\n"
      
      Config[:pretty_html] ? pretty(html) : html
    end
    
    private
    
    # pretty0 was copyied from CGI::pretty and modified for debugging.
    def pretty0(string, shift = "  ")
      lines = string.gsub(/(?!\A)<(?:.|\n)*?>/n, "\n\\0").gsub(/<(?:.|\n)*?>(?!\n)/n, "\\0\n")
      end_pos = 0
      while end_pos = lines.index(/^<\/(\w+)/n, end_pos)
        element = $1.dup
        start_pos = lines.rindex(/^\s*<#{element}/ni, end_pos)
        unless start_pos then
          raise Error, "start_tag not found. element = #{element.inspect}, end_pos = #{end_pos}, lines = #{lines[0, end_pos]}"
        end
        lines[start_pos ... end_pos] = "__" + lines[start_pos ... end_pos].gsub(/\n(?!\z)/n, "\n" + shift) + "__"
      end
      lines.gsub(/^((?:#{Regexp::quote(shift)})*)__(?=<\/?\w)/n, '\1')
    end
    
    def pretty(str)
      indent = '  '
      as_is = ['pre', 'a', 'title', 'h1', 'h2', 'h3', 'textarea', 'small', 'span']
      
      preserved = {}
      as_is.each_with_index do |tag, i|
        preserved[i] = []
        str = str.gsub(/(<#{tag}.*?>.*?<\/#{tag}>)/mi) {
          preserved[i] << $&
          i.chr
        }
      end
      
      begin
        result = pretty0(str, indent)
      rescue RegexpError => e
        # ignore RegexpError in pretty0. (BTS:117)
        result = str
      end
      
      result.gsub!(/^\s+$/, "")
      result.gsub!(/\n\n/, "\n")
      preserved.each do |i, queue|
        result.gsub!(/#{i.chr}/){ queue.shift }
      end
      
      result
    end
  end

  class RedirectActionResult
    def initialize(url)
      @url = url
    end
    
    def respond(cgi, flush_log, show_env, io = $stdout)
      io.print http_header(cgi)
    end
    
    def http_header(cgi)
      if defined?(MOD_RUBY) then
        Apache::request.headers_out.clear
      end
      cgi.header({'Location' => @url})
    end
  end


end
