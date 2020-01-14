=begin
  ConfigEnv - global parameter configuration
=end

require 'kagemai/mode'
require 'kagemai/error'
require 'kagemai/sharedfile'
require 'kagemai/cgi/action'
require 'kagemai/cgi/htmlhelper'
require 'kagemai/cgi/form_handler'

module Kagemai
  class ConfigEnv < Action
    include AdminAuthorization
    include FormHandler

    STAGE_ACTION_MAP = {
      '0' => :make_form, 
      '1' => :config_env
    }

    def execute()
      check_authorization()
      init_form_handler()
      action_map = Hash.new(:invalid_stage).update(STAGE_ACTION_MAP)
      send(action_map[@cgi.get_param('s', '0')])
    end

    def make_form()
      param = {
        :mode    => @mode,
        :lang    => @lang,
        :config  => Thread.current[:Config]
      }
      body = eval_template('config_env.rhtml', param)
      ActionResult.new(MessageBundle[:title_config_env],
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)

      
    end

    def config_env()
      CONFIG_VAR_NAMES.each do |name|
        is_string = Config[name.intern].kind_of?(String)

        if is_string then
          Config[name.intern] = @cgi.get_param(name, '').untaint
        else
          src = @cgi.get_param(name, nil)
          if src then
            th = Thread.start { 
              $SAFE = 4
              eval(src)
            }
            Config[name.intern] = th.value
          else
            Config[name.intern] = nil
          end
        end
      end

      SharedFile.write_open(Config.config_file) do |file|
        file.puts "module Kagemai"
        CONFIG_VAR_NAMES.each do |name|
          value = Config[name.intern]
          if value.kind_of?(String) then
            file.puts "  Config[:#{name}] = #{value.dump}"
          elsif value.nil? then
            file.puts "  Config[:#{name}] = nil"
          else
            file.puts "  Config[:#{name}] = #{value}"
          end
        end
        file.puts "end"
      end
      FileUtils.chmod2(Config[:file_mode], Config.config_file)
      @bts.invalidate_cache()
      
      if @lang != Config[:language] then
        @lang = Config[:language]
        MessageBundle.open(Config[:resource_dir], @lang, Config[:message_bundle_name])
      end
      param = {
        :mode   => @mode,
        :config => Thread.current[:Config],
        :config_file => Config.config_file
      }
      body = eval_template('config_env_done.rhtml', param)
      ActionResult.new(MessageBundle[:title_config_env],
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
    
    def self.name()
      'config_env'
    end
    Action::add_action(self)
  end
end
