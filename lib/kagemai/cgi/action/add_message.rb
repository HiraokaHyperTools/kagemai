=begin
  AddMessage

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
require 'kagemai/util'
require 'kagemai/message_bundle'
require 'kagemai/cgi/attachment_handler'
require 'kagemai/cgi/form_handler'
require 'kagemai/cgi/captcha'

module Kagemai
  class AddMessage < Action
    include AttachmentHandler
    include FormHandler
    include CaptchaHandler
    
    def execute()
      init_project(true)
      
      report_id = @cgi.get_param('id', '')
      raise ParameterError, 'report id not specified.' if report_id.empty?
      
      init_form_handler()
      
      if is_double_post?(ADD_MESSAGE_FORM) then
        return double_post_error_result()
      end
      
      captcha_auth = check_captcha()
      unless check_message_form(@project.report_type) && captcha_auth then
        @cgi.cached_attachments = save_attachments_to_session(project.report_type) 
        
        param = {
          :project    => @project,
          :report_id  => report_id,
          :params     => @cgi,
          :use_cookie => cookie_allowed?,
          :errors     => FormErrors.new(@errors),
          :email_notification => @email_notification,
          :use_captcha        => use_captcha?(),
          :captcha_error      => !captcha_auth,
        }
        
        init_captcha()
        start_form(ADD_MESSAGE_FORM)
        title = MessageBundle[:title_add_message_e]
        body = eval_template('message_form.rhtml', param)
        return ActionResult.new(title, header(), body, footer(), 
                                @css_url, @lang, @charset)
      end
      
      # get last message
      report_id = Util.untaint_digit_id(report_id)
      last_message = @project.load_report(report_id).last

      # add new message
      message = Message.new(@project.report_type)
      attachments = {}
      @project.report_type.each do |etype|
        if etype.kind_of?(FileElementType) then
          attachment = make_attachment(etype.id)
          if attachment then
            attachments[etype.id] = attachment
          end
        elsif (etype.report_attr && Mode::GUEST.current? && !etype.allow_guest) ||
              (etype.report_attr && Mode::GUEST.current? && etype.hide_from_guest) ||
              (etype.report_attr && Mode::USER.current? && !etype.allow_user) then
          default = etype.report_attr ? last_message[etype.id] : etype.default
          message[etype.id] = @cgi.get_param(etype.id, default)
        else
          message[etype.id] = @cgi.get_param(etype.id, etype.default)
        end
      end
      message.set_option('email_notification', email_notification_allowed?)
      message.ip_addr = @cgi.remote_addr
      
      store_attachments(@project, message, attachments)
      
      begin
        report = @project.add_message(report_id, message)
        title = MessageBundle[:title_add_message]
        param = {:report => report, :message => message}
        body  = eval_template('add_message.rhtml', param)
      rescue SpamError
        title = MessageBundle[:title_spam_error]
        body  = "<p>" + MessageBundle[:err_spam] + "</p>"
      end
      
      handle_cookies()
      ActionResult.new(title, header(), body, footer(), @css_url, @lang, @charset)
    end

    def self.name()
      'add_message'
    end
    Action::add_action(self)
  end
end
