=begin
  ViewReport - show report detail
=end

require 'kagemai/cgi/action'
require 'kagemai/util'
require 'kagemai/message_bundle'
require 'kagemai/cgi/form_handler'
require 'kagemai/cgi/captcha'

module Kagemai
  class ViewReport < Action
    include FormHandler
    include CaptchaHandler
    
    def execute()
      init_project()
      
      report_id = Util.untaint_digit_id(@cgi.get_param('id'))
      show_form = @cgi.get_param('s', '0') == '1'
      if show_form then
        @session = @cgi.create_session()
        init_captcha()
        start_form(ADD_MESSAGE_FORM)
      end
      
      errors = []
      report = @project.view_report(report_id)
      
      param = {
        :project            => @project,
        :report             => report,
        :email_notification => @email_notification,
        :use_cookie         => @use_cookie,
        :params             => report,
        :show_form          => show_form,
        :errors             => FormErrors.new,
        :use_captcha        => use_captcha?(),
      }
      body = eval_template('view_report.rhtml', param)
      
      ActionResult.new("#{report.id}: #{report['title']}", 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def self.name()
      'view_report'
    end
    Action::add_action(self)
  end
  
end
