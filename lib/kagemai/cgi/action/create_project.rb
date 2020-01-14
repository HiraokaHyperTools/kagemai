=begin
  CreateProject - プロジェクトを作成します

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

require 'kagemai/mode'
require 'kagemai/error'
require 'kagemai/cgi/action'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

module Kagemai
  class CreateProject < Action
    include AdminAuthorization
    include FormHandler

    STAGE_ACTION_MAP = {
      '0' => :make_create_form, 
      '1' => :create_project
    }

    def execute()
      check_authorization()
      init_form_handler()
      action_map = Hash.new(:invalid_stage).update(STAGE_ACTION_MAP)
      send(action_map[@cgi.get_param('s', '0')])
    end

    def make_create_form(store = Config[:default_store], template = Config[:default_template], error = false)
      param = {
        :mode              => @mode,
        :bts               => @bts,
        :errors            => FormErrors.new(@errors),
        :values            => @cgi,
        :fold_column       => Config[:fold_column],
        :css_url           => Config[:css_url],
        :subject_id_figure => Config[:subject_id_figure],
        :store             => store,
        :template          => template,
        :top_page_options  => top_page_options(error)
      }
      body = eval_template('create_project.rhtml', param)
      ActionResult.new(MessageBundle[:title_create_project],
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def create_project()
      # Check required parameters.
      requires = ['project_name', 'description', 'template']
      requires.each do |id|
        check_form_value(id, nil, false)
      end

      # Check project_id inclues only [A-Za-z0-9] and
      # does not exist.
      if check_form_value('project_id', nil, false) then
        if /^#{Project::ID_REGEXP_STR}$/ =~ @cgi.get_param('project_id') then
          project_id = Util.untaint_path(@cgi.get_param('project_id').downcase)
          
          if @bts.exist_project?(project_id) then
            @errors[:err_exist_project] = ['project_id']
          elsif @cgi.get_param('project_id') == 'CVS' then
            @errors[:err_limit_cvs] = ['project_id']
          end
        else
          @errors[:err_ascii_only] = ['project_id']
        end
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
        add_error(:err_subject_id_figure, 'subject_id_figure')
      end

      unless valid_form? then
        store, = @cgi.get_param('store', Config[:default_store])
        template = @cgi.get_param('template', Config[:default_template])
        return make_create_form(store, template, true) # error
      end

      options = {
        'id'                => Util.untaint_path(@cgi.get_param('project_id')),
        'name'              => @cgi.get_param('project_name'),
        'description'       => @cgi.get_param('description'),
        'admin_address'     => @cgi.get_param('admin_address'),
        'post_address'      => @cgi.get_param('post_address'),
        'notify_addresses'  => notify_addresses,
        'subject_id_figure' => @cgi.get_param('subject_id_figure'),
        'fold_column'       => @cgi.get_param('fold_column'),
        'use_filter'        => @cgi.get_param('use_filter'),
        'css_url'           => @cgi.get_param('css_url', ''),
        'store'             => @cgi.get_param('store'),
        'template'          => Util.untaint_path(@cgi.get_param('template')),
        'top_page_options'  => top_page_options(false),
        'lang'              => @lang,
        'charset'           => @charset
      }

      project = @bts.create_project(options)
      body = eval_template('create_project_done.rhtml', {:mode => @mode, :project => project})
      ActionResult.new(MessageBundle[:title_create_project_done],  
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

    def top_page_options(error)
      return TOP_PAGE_OPTIONS unless error

      options = {}

      TOP_PAGE_OPTIONS.each do |name, default|
        v = @cgi.fetch('top_page_' + name, false)
        options[name] = v.kind_of?(String) ? (v == 'on') : v
      end

      options
    end

    def self.name()
      'create_project'
    end    
    Action::add_action(self)
  end

end
