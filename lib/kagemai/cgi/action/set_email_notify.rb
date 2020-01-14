=begin
  set email notifications
=end

require 'kagemai/cgi/action'
require 'kagemai/cgi/form_handler'

module Kagemai
  class SetEmailNotification < Action
    include AdminAuthorization
    include FormHandler

    def execute()
      check_authorization()
      init_project()

      report_id = Util.untaint_digit_id(@cgi.get_param('id'))
      report = @project.load_report(report_id)

      report.each do |message|
        if @cgi.get_param(message['email'], '') == 'on' then
          message.set_option('email_notification', true)
        else
          message.set_option('email_notification', false)
        end
      end

      @project.update_report(report)

      param = {
        :project            => @project,
        :report             => report,
        :email_notification => @email_notification,
        :use_cookie         => @use_cookie,
        :params             => report,
        :show_form          => false,
        :errors             => FormErrors.new
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
      'set_email_notification'
    end
    Action::add_action(self)
    
  end
end
