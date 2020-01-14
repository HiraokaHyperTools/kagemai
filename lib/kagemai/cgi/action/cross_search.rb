=begin
  CrossSearch : search any or all projects
=end

require 'kagemai/cgi/action'
require 'kagemai/message_bundle'

module Kagemai
  class CrossSearch < Action
    def execute()
      @limit  = @cgi.get_param('limit',  50).to_i
      @offset = @cgi.get_param('offset', '0').to_i
      @order  = @cgi.get_param('order',  'report_id')
      
      keyword = @cgi.get_param('keyword', '')
      if keyword.empty? then
        show_form()
      else
        do_search(keyword)
      end
    end
    
    def show_form()
      body = eval_template('csearch.rhtml', {:mode => @mode, :bts => @bts})
      ActionResult.new(MessageBundle[:title_csearch_form], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def do_search(keyword)
      ttype       = @cgi.get_param('ttype', 'all')
      projects    = @cgi.get_param('projects', '').split(/,\n/)
      case_insensitive = @cgi.get_param('case_insensitive') == 'on'
      
      app = CGIApplication.instance()
      total, results = app.cross_search(keyword, case_insensitive, 
                                        ttype, projects,
                                        @limit, @offset, @order)
      
      params = {
        :mode      => @mode, 
        :bts       => @bts,
        :ttype     => ttype,
        :projects  => projects,
        :keyword   => keyword,
        :case_insensitive => case_insensitive,
        :results   => results,
        :total     => total
      }
      body = eval_template('csearch_result.rhtml', params)
      ActionResult.new(MessageBundle[:title_csearch_result],
                       header(), 
                       body,
                       footer(),
                       @css_url,
                       @lang,
                       @charset)
    end
    
    def search(project, keyword, attr_cond, case_insensitive)
      search_elements = Hash.new(false)
      condition = SearchCondOr.new
      project.report_type.each do |etype|
        search_elements[etype.id] = true
        condition.or(SearchInclude.new(etype.id, keyword, case_insensitive))
      end
      project.search(attr_cond, condition, true, @limit, @offset, @order)
    end
    
    def self.name()
      'csearch'
    end
    Action::add_action(self)
    
    def self.href(base_url, project_id = nil)
      param = {'action' => name()}
      project_id ? nil : MessageBundle[:action_csearch].href(base_url, param)
    end
  end
end
