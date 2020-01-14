=begin
  ConfigProject - プロジェクトの設定変更

  Copyright(C) 2002-2004 FUKUOKA Tomoyuki.

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

require 'kagemai/mode'
require 'kagemai/error'
require 'kagemai/cgi/action'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

module Kagemai
  class ConfigProject < Action
    include AdminAuthorization
    include FormHandler

    STAGE_ACTION_MAP = {
      '0' => :make_config_select_form, 
      '1' => :make_config_form,
      '2' => :config_project
    }

    def execute()
      check_authorization()
      init_form_handler()
      action_map = Hash.new(:invalid_stage).update(STAGE_ACTION_MAP)
      send(action_map[@cgi.get_param('s', '0')])
    end

    def make_config_select_form()
      param = {:mode => @mode, :bts => @bts}
      body = eval_template('config_project_select.rhtml', param)
      ActionResult.new(MessageBundle[:title_config_project_select], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def make_config_form(error = false)
      init_project()

      unless error then
        values = @project
        store  = @project.db_manager_class
        notify_address = @project.notify_addresses.join("\n")
        tp_opt = @project.top_page_options
      else
        values = @cgi
        store  = @bts.validate_store(@cgi.get_param('store', ''))
        notify_address = @cgi.get_param('notify_addresses', '').to_s.escape_h
        tp_opt = top_page_options(values)
      end  
      
      param = {
        :mode    => @mode, 
        :bts     => @bts,
        :project => @project,
        :errors  => FormErrors.new(@errors),
        :values  => values,
        :store   => store,
        :notify_addresses => notify_address,
        :top_page_options  => tp_opt
      }
      body = eval_template('config_project.rhtml', param)
      ActionResult.new(MessageBundle[:title_config_project] % @project.id, 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def config_project()
      init_project()

      # Check required parameters.
      requires = ['name', 'description']
      requires.each do |id|
        check_form_value(id, nil, false)
      end

      # Check optional parameters.
      # email address は、email address check をかける
      email_fields = ['admin_address', 'post_address']
      email_fields.each do |id|
        check_form_value(id, 'valid-address@daifukuya.com', true)
      end

      # Check integer parameters.
      int_params = ['subject_id_figure', 'fold_column']
      int_params.each do |id|
        check_int_value(id)
      end

      notify_addresses = @cgi.get_param('notify_addresses', '').split(/[, \t\r\n]+/m).compact
      notify_addresses.each do |address|
        unless valid_email_address?(address) then
          Logger.debug('FormHandler', "email check failed: address = #{address.inspect}")
          add_error(:err_invalid_email_address, 'notify_addresses')
          break
        else
          Logger.debug('FormHandler', "notify_address = #{address.inspect}")
          address.untaint
        end
      end

      c = @cgi.get_param('subject_id_figure', '-1').to_i
      unless (0 <= c && c <= 7) then
        add_error(:err_subject_tag_figure, 'subject_id_figure')
      end

      # store id check
      # 無効な Store じゃないかチェックするべき
      store_class = @bts.validate_store(@cgi.get_param('store'))

      unless valid_form? then
        return make_config_form(true) # error
      end

      ## ここでデータベースの変換を行う。
      @bts.convert_store(@project.id, 
                         @project.charset, 
                         @project.report_type, 
                         @project.db_manager_class,
                         store_class)
      @project.invalidate_cache('project', nil)
      
      options = {
        'name'              => @cgi.get_param('name'),
        'description'       => @cgi.get_param('description'),
        'admin_address'     => @cgi.get_param('admin_address'),
        'post_address'      => @cgi.get_param('post_address'),
        'notify_addresses'  => notify_addresses, 
        'subject_id_figure' => @cgi.get_param('subject_id_figure'),
        'fold_column'       => @cgi.get_param('fold_column'),
        'use_filter'        => (@cgi.get_param('use_filter', 'false') == 'true'),
        'css_url'           => @cgi.get_param('css_url', ''),
        'store'             => @cgi.get_param('store'),
        'top_page_options'  => top_page_options(@cgi),
        'lang'              => @project.lang,
        'charset'           => @project.charset
      }
      @bts.save_project_config(@project.id, options)

      # reopen project
      project = @bts.open_project(@project.id)
      param = {:project => project, :mode => @mode}
      body = eval_template('config_project_done.rhtml', param)
      ActionResult.new(MessageBundle[:title_config_project_done] % project.id, 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end

    def invalid_stage()
      raise ParameterError, 'invalid parameter s'
    end

    def top_page_options(values)
      options = {}

      TOP_PAGE_OPTIONS.each do |name, default|
        v = values.fetch('top_page_' + name, false)
        options[name] = v.kind_of?(String) ? (v == 'on') : v
      end

      options
    end

    def self.name()
      'config_project'
    end
    Action::add_action(self)
  end

end
