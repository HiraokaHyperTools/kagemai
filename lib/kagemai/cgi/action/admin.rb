=begin
  admin.rb - create top page for administrator
=end

require 'kagemai/mode'
require 'kagemai/error'
require 'kagemai/cgi/action'
require 'kagemai/message_bundle'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

module Kagemai
  class AdminPage < Action
    include AdminAuthorization

    def execute()
      check_authorization()
      
      @cgi.session_gc()
      
      body = eval_template('admin.rhtml', {:mode => @mode})
      ActionResult.new(MessageBundle[:title_admin], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang, 
                       @charset)
    end

    def self.name()
      'admin'
    end
    
    def self.href(base_url, project_id)
      MessageBundle[:action_admin].href(base_url, {'action' => name()})
    end    
    
    Action::add_action(self)
  end
  
end
