=begin
  DeleteProject
=end

require 'kagemai/mode'
require 'kagemai/error'
require 'kagemai/cgi/action'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

module Kagemai
  class DeleteProject < Action
    include AdminAuthorization
    include FormHandler

    STAGE_ACTION_MAP = {
      '0' => :make_delete_form, 
      '1' => :confirm_delete,
      '2' => :delete_project
    }

    def execute()
      check_authorization()
      init_form_handler()
      action_map = Hash.new(:invalid_stage).update(STAGE_ACTION_MAP)
      send(action_map[@cgi.get_param('s', '0')])
    end

    def make_delete_form(error = false)
      param = {:mode => @mode, :bts => @bts}
      body = eval_template('delete_project.rhtml', param)
      ActionResult.new(MessageBundle[:title_delete_project], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def confirm_delete()
      init_project()
      param = {:mode => @mode, :project => @project}
      body = eval_template('delete_project_confirm.rhtml', param)
      ActionResult.new(MessageBundle[:title_delete_project_confirm], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def delete_project()
      project_id = Util.untaint_path(@cgi.get_param('project'))
      confirm = @cgi.get_param('confirm')

      if confirm == 'yes' || confirm == 'yes_all' then
        delete_all = confirm == 'yes_all'
        project, del_name = @bts.delete_project(project_id, delete_all)
        
        param = {
          :mode       => @mode,
          :project    => project,
          :delete_all => delete_all,
          :del_name   => del_name
        }
                
        body = eval_template('delete_project_done.rhtml', param)
        ActionResult.new(MessageBundle[:title_delete_project_delete], 
                         header(), 
                         body, 
                         footer(), 
                         @css_url, 
                         @lang,
                         @charset)
      else
        make_delete_form()
      end
    end


    def invalid_stage()
      raise ParameterError, 'invalid parameter s'
    end

    def self.name()
      'delete_project'
    end
    Action::add_action(self)
  end

end
