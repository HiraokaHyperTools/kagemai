=begin
  NewForm - make new report form
=end

require 'digest/md5'
require 'kagemai/cgi/action'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'
require 'kagemai/cgi/captcha'

module Kagemai
  class NewForm < Action
    include FormHandler
    include CaptchaHandler
    
    def execute()
      init_project(true)
      init_captcha()      
      start_form(NEW_REPORT_FORM)
      
      param = {
        :cgi                => @cgi,
        :project            => @project,
        :errors             => FormErrors.new,
        :email_notification => @email_notification,
        :allow_cookie       => @use_cookie,
        :use_captcha        => use_captcha?(),
        :captcha_error      => false
      }
      
      body = eval_template('new_form.rhtml', param)
      ActionResult.new(MessageBundle[:title_new_report], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end

    def self.name()
      'new_form'
    end
    Action::add_action(self)

    def self.href(base_url, project_id)
      param = {'action' => name(), 'project' => project_id}
      project_id ? MessageBundle[:action_new_report].href(base_url, param) : nil
    end
  end
end
