=begin
  Projects - show projects list page.
=end

require 'kagemai/cgi/action'
require 'kagemai/message_bundle'

module Kagemai
  class Projects < Action
    def execute()
      body = eval_template('projects.rhtml', {:bts => @bts})
      ActionResult.new(MessageBundle[:title_projects], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def self.name()
      'projects'
    end
    Action::add_action(self)
    Action::set_default_action(self)
    
    def self.default?()
      true
    end
    
    def self.href(base_url, project_id)
      MessageBundle[:action_projects].href(base_url)
    end    
  end
end
