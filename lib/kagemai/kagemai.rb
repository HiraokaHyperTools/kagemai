=begin
  kagemai.rb -- KAGEMAI : A Bug Tracking System.
  Copyright(C) 2002-2008 FUKUOKA Tomoyuki.
=end

begin
  require 'rubygems'
rescue LoadError 
  # ignore
end

require 'fileutils'
require 'kagemai/config'
require 'kagemai/bts'
require 'kagemai/cgi/action'
require 'kagemai/error'

module Kagemai
  CODENAME = 'bk'
  VERSION  = '0.9.0'
  URL      = 'http://www.daifukuya.com/kagemai/'
  
  class CGIApplication
    def self.instance()
      # Get applicatoin object from TLS.
      application = Thread.current[:CGIApplication]
      unless application
        raise Error, 'cannnot retrieve CGIApplication object from TLS.'
      end
      return application
    end
    
    def initialize(cgi, mode)
      @cgi = cgi
      @mode = mode
      @bts = BTS.new(Config[:project_dir])
      @project = nil
      
      # check tmpdir
      unless File.exist?(Config[:tmp_dir]) then
        FileUtils.mkpath(Config[:tmp_dir])
        FileUtils.chmod(Config[:dir_mode] & 02770, Config[:tmp_dir])
      end
      
      @lang = Util.untaint_path(@cgi.get_param('lang', Config[:language]))
      MessageBundle.open(Config[:resource_dir], @lang, Config[:message_bundle_name])
      
      # initialize TLS
      Thread.current[:element_renderer] = {}
            
      # Store application object to TLS.
      Thread.current[:CGIApplication] = self
      CGIApplication.instance()
    end
    attr_reader :cgi, :mode, :bts, :lang
    
    def action()
      name = @cgi.get_param('action', '')
      @actions, @default_action = Action::load(Config[:action_dir])
      action_class = name.empty? ? @default_action : @actions[name]
      
      if action_class then
        action = action_class.new(@cgi, @bts, @mode, @lang)
        project = action.project
        
        type = action.cache_type
        key = @mode.url + ':' + action.cache_key
        
        if project && Config[:use_html_cache] && !$KAGEMAI_DEBUG then
          result = project.load_cache(type, key)
        end
        result = action.execute() unless result
        
        if project then
          if Config[:use_html_cache] then
            project.save_cache(type, key, result)
          else
            project.invalidate_cache(type, key)
          end
        end
        
        result
      else
        raise ParameterError, "No such action : #{name}"
      end
    end
    
    def cross_search(keyword, case_insensitive = true, 
                     ttype = 'all', projects = [],
                     limit = 50, offset = 0, order = 'report_id')
      results = {}
      total   = 0
      
      keywords = keyword.split(/[\s]+/oe)
      
      attr_cond = NullSearchCond.new(true)
      @bts.each_project do |project|
        if ttype == 'all' || projects.include?(project.id) then
          result = do_search(project, keywords, attr_cond, case_insensitive, limit, offset, order)
          results[project.id] = result
          total = total + result.total
        end
      end
      [total, results]
    end
    
    private
    
    def do_search(project, keywords, attr_cond, case_insensitive, limit, offset, order)
      search_elements = Hash.new(false)
      
      condition = SearchCondOr.new
      project.report_type.each do |etype|
        if @mode.name == "mode_guest" && etype.hide_from_guest? then
          next
        end
        search_elements[etype.id] = true
        if keywords.size > 1 then
          acond = SearchCondAnd.new
          keywords.each do |k|
            acond.and(SearchInclude.new(etype.id, k, case_insensitive))
          end
        else
          acond = SearchInclude.new(etype.id, keywords[0], case_insensitive)
        end
        condition.or(acond)
      end
      project.search(attr_cond, condition, true, limit, offset, order)
    end
    
  end
end
