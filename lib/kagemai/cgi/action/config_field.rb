=begin
  ConfigFiled - configure report elements and options
=end

require 'kagemai/mode'
require 'kagemai/error'
require 'kagemai/cgi/action'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

module Kagemai
  class ConfigField < Action
    include AdminAuthorization
    include FormHandler

    STAGE_ACTION_MAP = {
      '0' => :make_config_select_form, 
      '1' => :make_config_main_form,
      '2' => :make_field_edit_form,
      '3' => :make_field_add_form,
      '10' => :add_field,
      '11' => :delete_field,
      '12' => :edit_field,
      '13' => :up_field,
      '14' => :down_field,
    }

    def execute()
      check_authorization()
      init_form_handler()
      action_map = Hash.new(:invalid_stage).update(STAGE_ACTION_MAP)
      send(action_map[@cgi.get_param('s', '0')])
    end
    
    def self.name()
      'config_field'
    end
    Action::add_action(self)

    private

    def make_config_select_form(error = false)
      param = {
        :mode => @mode,
        :bts  => @bts
      }
      body = eval_template('config_field_select.rhtml', param)
      ActionResult.new(MessageBundle[:title_field_select], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang, 
                       @charset)

    end

    def make_config_main_form()
      init_project()

      aparams = {'action' => ConfigField.name, 'project' => @project.id }
      param = {
        :mode     => @mode,
        :project  => @project,
        :edit_p   => {'s' => '2'}.update(aparams),
        :order_p  => {'s' => '4'}.update(aparams),
        :delete_p => {'s' => '11'}.update(aparams),
        :up_p     => {'s' => '13'}.update(aparams),
        :down_p   => {'s' => '14'}.update(aparams),
        :add_p    => {'action' => ConfigField.name, 'project' => @project.id, 's' => '3'}
      }
      body = eval_template('config_field_main.rhtml', param)

      ActionResult.new(MessageBundle[:title_field_main], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

    end

    def make_field_edit_form(error = false)
      init_project()
      etype = @project.report_type[@cgi.get_param('f')]
      unless etype then
        raise ParameterError, "Invalid field id: f = '#{@cgi.get_param('f')}'"
      end
      
      param = {
        :mode        => @mode,
        :project     => @project,
        :etype_class => etype.class,
        :etype_id    => etype.id,
        :values      => error ? error_values(etype.class) : etype,
        :errors      => FormErrors.new(@errors)
      }
      body = eval_template('config_field_edit.rhtml', param)
      
      ActionResult.new(MessageBundle[:title_field_edit] % etype.name, 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end
    
    def make_field_add_form(error = false)
      init_project()

      etype_class = validate_etype_class(@cgi.get_param('f', nil))
      title = MessageBundle[:title_field_add] % etype_class.name
      values = Hash.new([''])
      
      unless error then
        values['default'] = etype_class.default_value()
        options = etype_class.extended_options(nil) + etype_class.boolean_options
        options.each do |opt|
          values[opt.name] = opt.default
        end
      else
        values = error_values(etype_class)
      end

      param = {
        :mode        => @mode,
        :project     => @project,
        :values      => values,
        :next_stage  => '10',
        :etype_class => etype_class,
        :errors      => FormErrors.new(@errors)
      }
      body = eval_template('config_field_add.rhtml', param)

      ActionResult.new(title, 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end    

    def add_field()
      init_project()
      etype_class = validate_etype_class(@cgi.get_param('f'))
      ['id', 'name'].each do |name|
        validate_required_value(name)
      end
      
      if @project.report_type[@cgi.get_param('id', '').downcase] then
        add_error(:err_exist_id, 'id')
      end
      
      options = {
        'id' => @cgi.get_param('id', '').downcase,
        'name' => @cgi.get_param('name'),
        'description' => @cgi.get_param('description'),
      }
      etype_class.boolean_options.each do |bopt|
        options[bopt.name] = @cgi.get_param(bopt.name, false)
        Logger.debug('Config', "@cgi.get_param(#{bopt.name}) = #{@cgi.get_param(bopt.name)}")
        Logger.debug('Config', "#{bopt.name} = #{options[bopt.name].inspect}")
      end

      etype_class.extended_options(nil).each do |opt|
        options[opt.name] = @cgi.get_param(opt.name, opt.default)
      end

      default = @cgi.get_param('default', '')
      if default != 'nil' then
        options['default'] = default
      elsif @project.size > 0 then
        add_error(:err_config_field_default, 'default')
      end

      report_attr = @cgi.get_param('report_attr', '')
      allow_guest = @cgi.get_param('allow_guest', '')
      if !report_attr.empty? && allow_guest.empty? && default == 'nil' then
        add_error(:err_config_field_default2, 'default')
      end

      unless valid_form? then
        return make_field_add_form(true) # error
      end

      etype = etype_class.new(options)
      if etype_class.ancestors.include?(SelectElementType) then
        choices = @cgi.get_param('choices', '').split(/[,\r\n]/m)
        choices = choices.collect{|c| c.strip.empty? ? nil : c.strip}.compact()
        Logger.debug('Config', "add field: choices  = #{choices.inspect}")

        choices.each_with_index do |c, i|
          c_opt = {
            'id'          => c,
            'sdesc'       => @cgi.get_param("c#{i}_sdesc", ''),
            'description' => @cgi.get_param("c#{i}_description", ''),
            'show_topics' => @cgi.get_param("c#{i}_show_topics", '')
          }
          Logger.debug('Config', "add field: choice = #{c}, option  = #{c_opt.inspect}")

          choice = SelectElementType::Choice.new(c_opt)
          etype.add_choice(choice)
        end
        
        if @cgi.get_param('show_topics') == "on" then
          unless choices.empty? || @cgi.get_param('config_choice', nil) == 'yes' then
            return make_config_choice_form(etype_class.to_s, etype, options, choices, 10)
          end
        end
      end

      @project.add_element_type(etype)

      make_config_main_form()
    end

    def edit_field()
      init_project()

      etype = @project.report_type[@cgi.get_param('f')]
      unless etype then
        raise ParameterError, "Invalid field id: etype_id = '#{@cgi.get_param('f').inspect}'"
      end

      ['name'].each do |name|
        validate_required_value(name)
      end

      options = {
        'name' => @cgi.get_param('name'),
        'description' => @cgi.get_param('description')
      }
      etype.class.boolean_options.each do |bopt|
        options[bopt.name] = @cgi.get_param(bopt.name, false)
        Logger.debug('Config', "@cgi.get_param(#{bopt.name}) = #{@cgi.get_param(bopt.name).inspect}")
        Logger.debug('Config', "#{bopt.name} = #{options[bopt.name].inspect}")
      end

      etype.class.extended_options(nil).each do |opt|
        options[opt.name] = @cgi.get_param(opt.name, opt.default)
      end

      default = @cgi.get_param('default', '')
      options['default'] = default != 'nil' ? default : nil
      
      if @project.size > 0 && etype.default != nil && options['default'] == nil then
        add_error(:err_config_field_default, 'default')
      end

      report_attr = @cgi.get_param('report_attr', '')
      allow_guest = @cgi.get_param('allow_guest', '')
      if !report_attr.empty? && allow_guest.empty? && default == 'nil' then
        add_error(:err_config_field_default2, 'default')
      end

      unless valid_form? then
        return make_field_edit_form(true) # error
      end

      options.each do |key, value|
        etype[key] = value
      end
 
      if etype.class.ancestors.include?(SelectElementType) then
        choices = @cgi.get_param('choices', '').split(/[,\r\n]/m)
        choices = choices.collect{|c| c.strip.empty? ? nil : c.strip}.compact()
        Logger.debug('Config', "edit field: choices  = #{choices.inspect}")

        config_choice = @cgi.get_param('config_choice', nil) == 'yes'
        
        new_choices = []
        choices.each_with_index do |c, i|
          c_opt = {
            'id'          => c,
            'sdesc'       => @cgi.get_param("c#{i}_sdesc", ''),
            'description' => @cgi.get_param("c#{i}_description", ''),
            'show_topics' => @cgi.get_param("c#{i}_show_topics", '')
          }
          Logger.debug('Config', "edit field: choice = #{c}, option  = #{c_opt.inspect}")

          choice = nil
          if config_choice then
            choice = SelectElementType::Choice.new(c_opt)
          else
            choice = etype.find{|i| i.id == c}
            unless choice then
              choice = SelectElementType::Choice.new(c_opt)
            end
          end
          new_choices << choice
        end
        etype.set_choices(new_choices)

        if @cgi.get_param('show_topics') == "on"  then
          unless choices.empty? || config_choice then
            return make_config_choice_form(etype.id, etype, options, choices, 12)
          end
        end
      end

      @project.change_element_type(etype)
      make_config_main_form()
    end

    def make_config_choice_form(etype_id, etype, options, choices, next_stage)
      param = {
        :mode       => @mode,
        :project    => @project,
        :etype_id   => etype_id,
        :etype      => etype,
        :options    => options,
        :choices    => choices,
        :next_stage => next_stage
      }
      body = eval_template('config_choice.rhtml', param)
      ActionResult.new(MessageBundle[:title_config_choice], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
      
    end

    def delete_field()
      init_project()
      etype_id = @cgi.get_param('f', nil)

      @project.delete_element_type(etype_id)

      make_config_main_form()
    end

    def up_field()
      init_project()
      etype_id = @cgi.get_param('f', nil)

      etypes = @project.report_type.to_a()
      (1...etypes.size).each do |i|
        if etypes[i].id == etype_id then
          t = etypes[i - 1]
          etypes[i - 1] = etypes[i]
          etypes[i] = t
          break
        end
      end

      @project.report_type.set_element_types(etypes)
      @project.save_report_type()

      make_config_main_form()
    end

    def down_field()
      init_project()
      etype_id = @cgi.get_param('f', nil)

      etypes = @project.report_type.to_a()
      (0...(etypes.size - 1)).each do |i|
        if etypes[i].id == etype_id then
          t = etypes[i + 1]
          etypes[i + 1] = etypes[i]
          etypes[i] = t
          break
        end
      end

      @project.report_type.set_element_types(etypes)
      @project.save_report_type()

      make_config_main_form()
    end
    
    def validate_etype_class(etype_id)
      ElementType.each_children do |ec| 
        if ec.to_s == etype_id then
          return ec
        end
      end
      raise ParameterError, "Invalid Element Type: #{etype_id}"
    end

    def invalid_stage()
      raise ParameterError, 'invalid parameter s'
    end

    def error_values(etype_class)
      names = ['id', 'name', 'description', 'default']
      names += etype_class.option_names()
      
      values = {}
      names.each do |name|
        values[name] = @cgi.get_param(name)
      end
      
      values
    end    
  end  
end
