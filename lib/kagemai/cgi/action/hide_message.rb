=begin
  hide_message_rb : Hide a message as spam.
=end

require 'kagemai/cgi/action'
require 'kagemai/cgi/form_handler'

module Kagemai
  class HideMessage < Action
    include FormHandler
    
    def execute()
      init_project()
      
      report_id = Util.untaint_digit_id(@cgi.get_param('id'))
      message_id = Util.untaint_digit_id(@cgi.get_param('m'))
      hide = @cgi.get_param('hide', 'true') == 'true'
      
      report = @project.load_report(report_id)
      if hide && report.visible_size == 1 then
        raise InvalidOperationError, "last message can not be hide."
      end
      
      # hide message
      report.at(message_id).hide = hide
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

      result_url = @project.url + "&action=#{ViewReport.name}&id=#{report_id.to_s}"
      
      RedirectActionResult.new(result_url)
    end
    
    def self.name()
      'hide_message'
    end
    Action::add_action(self)
  end
end
