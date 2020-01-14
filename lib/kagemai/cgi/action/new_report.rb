=begin
  NewReport - add new report to store

  Copyright(C) 2002-2008 FUKUOKA Tomoyuki.

  This file is part of KAGEMAI.  

  KAGEMAI is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
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
      
      captcha_auth = check_captcha()
      unless check_message_form(@project.report_type) && captcha_auth then
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
        action_result = ActionResult.new(MessageBundle[:title_new_report_e], 
                                         header(), 
                                         body, 
                                         footer(), 
                                         @css_url, 
                                         @lang,
                                         @charset)
        return action_result
      end
            
      # create first message of new report.
      message = Message.new(@project.report_type)
      attachments = {}
      @project.report_type.each do |etype|
        unless etype.kind_of?(FileElementType)
          message[etype.id] = @cgi.get_param(etype.id, etype.default)
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
        body   = eval_template('new_report.rhtml', {:report => report, :message => message})
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
