=begin
  SplitReport

  Copyright(C) 2002, 2003 FUKUOKA Tomoyuki.

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
require 'kagemai/cgi/form_handler'

module Kagemai
  class SplitReport < Action
    include FormHandler

    ACTION_MAP = {
      '0' => :make_form,
      '1' => :split_report
    }

    def execute()
      init_project()

      @report_id = Util.untaint_digit_id(@cgi.get_param('id'))
      @report = @project.load_report(@report_id)

      action_map = Hash.new(:invalid_action).update(ACTION_MAP)
      send(action_map[@cgi.get_param('s', '0')])
    end

    def make_form()
      errors = []
      param = {
        :project            => @project,
        :report             => @report,
        :email_notification => @email_notification,
        :use_cookie         => @use_cookie,
        :errors             => FormErrors.new
      }
      body = eval_template('split_report.rhtml', param)

      ActionResult.new("#{@report.id}: #{@report['title']}", 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end

    def split_report()
      left  = []
      split = []
      @report.each do |message|
        message.modified = true
        if @cgi.get_param("split#{message.id}", 'off') == 'on' then
          split << message
        else
          left << message
        end
      end
      if left.empty? || split.empty? then
        raise InvalidOperationError, MessageBundle[:err_invalid_split]
      end

      # make new report
      new_report = @project.new_report(split.shift, false)
      split.each {|m| new_report.add_message(m)}
      @project.store_report(new_report)
      
      # remake original report
      report = Report.new(@report.type, @report.id)
      left.each {|m| report.add_message(m)}
      @project.remake_report(report)
      
      param = {
        :report     => report,
        :new_report => new_report
      }
      body = eval_template('split_report_done.rhtml', param)

      ActionResult.new(MessageBundle[:title_split_done], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end

    def invalid_action()
      raise ParameterError, 'invalid parameters'
    end

    def self.name()
      'split_report'
    end
    Action::add_action(self)
    
    def self.href(project_id, report_id)
      base_url = CGIApplication.instance.mode.url
      param = {
        'action' => name(), 
        'project' => project_id, 
        'id' => report_id.to_s, 
        's' => '0'
      }
      MessageBundle[:action_split_report].href(base_url, param)
    end    
  end
end
