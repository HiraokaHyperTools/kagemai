=begin
  NewReport - add new report to store
=end

require 'kagemai/cgi/action'
require 'kagemai/cgi/attachment_handler'
require 'kagemai/cgi/form_handler'
require 'kagemai/cgi/captcha'

module Kagemai
  class NewReport < Action
    include AttachmentHandler
    include FormHandler
    include CaptchaHandler
    
    def execute()
      init_project(true)
      init_form_handler()
      
      if is_double_post?(NEW_REPORT_FORM) then
        return double_post_error_result()
      end
      
      restore_values(@project.report_type)
      captcha_auth = check_captcha()
      submit_back = @cgi.get_param('submit_back')
      unless !submit_back && validate_message_form(@project.report_type) && captcha_auth then
        @cgi.cached_attachments = save_attachments_to_session(project.report_type) 
        
        param = {
          :cgi                => @cgi,
          :project            => @project,
          :errors             => FormErrors.new(@errors),
          :email_notification => email_notification_allowed?,
          :allow_cookie       => cookie_allowed?,
          :use_captcha        => use_captcha?(),
          :captcha_error      => !captcha_auth,
        }
        
        init_captcha()
        start_form(NEW_REPORT_FORM)
        body = eval_template('new_form.rhtml', param)
        title = submit_back ? MessageBundle[:title_new_report] : MessageBundle[:title_new_report_e]
        action_result = ActionResult.new(title, header(), body, footer(), @css_url, @lang, @charset)
        return action_result
      end
      
      if @cgi.get_param('submit_preview') then
        @cgi.cached_attachments = save_attachments_to_session(project.report_type) 
        message = save_values(@project.report_type, @cgi.cached_attachments)
        skip_captcha()
        start_form(NEW_REPORT_FORM)
        param = {:message => message, :preview => true, :project=> @project}
        body = eval_template('new_report.rhtml', param)
        title = MessageBundle[:title_new_report_preview]
        return ActionResult.new(title, header(), body, footer(), @css_url, @lang, @charset)
      end
      
      # create first message of new report.
      message = Message.new(@project.report_type)
      attachments = {}
      @project.report_type.each do |etype|
        unless etype.kind_of?(FileElementType)
          message[etype.id] = @cgi.get_param(etype.id, etype.empty_value)
        else
          attachment = make_attachment(etype.id)
          if attachment then
            attachments[etype.id] = attachment
          end
        end
      end
      message.set_option('email_notification', email_notification_allowed?)
      message.ip_addr = @cgi.remote_addr
      
      store_attachments(@project, message, attachments)
      begin
        report = @project.new_report(message)
        param = {:report => report, :message => message, :preview => false}
        body   = eval_template('new_report.rhtml', param)
        title  = MessageBundle[:title_new_report_added]
      rescue SpamError
        title = MessageBundle[:title_spam_error]
        body  = "<p>" + MessageBundle[:err_spam] + "</p>"
      end
      
      handle_cookies()
      ActionResult.new(title, header(), body, footer(), @css_url, @lang, @charset)      
    end

    def self.name()
      'new_report'
    end
    Action::add_action(self)
  end
end
