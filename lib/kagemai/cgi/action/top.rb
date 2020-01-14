=begin
  Top - show project top page.
=end

require 'kagemai/cgi/action'
require 'kagemai/message_bundle'

module Kagemai
  class Top < Action
    def initialize(cgi, bts, mode, lang)
      super
      init_project()
    end
    
    def cache_type()
      'project'
    end
    
    def execute()
      body = eval_template('topics.rhtml', {:mode => @mode, :project => @project})
      ActionResult.new(MessageBundle[:title_top] % @project.name, 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def self.name()
      'top'
    end
    Action::add_action(self)

    def self.href(base_url, project_id)
      param = {'action' => name(), 'project' => project_id}
      project_id ? MessageBundle[:action_top].href(base_url, param) : nil
    end
  end
end
