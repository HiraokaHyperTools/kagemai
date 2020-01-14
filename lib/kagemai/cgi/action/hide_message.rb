=begin
  hide_message_rb : Hide a message as spam.

  Copyright(C) 2008 FUKUOKA Tomoyuki.

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
