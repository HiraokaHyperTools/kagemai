=begin
  bts.rb - Bug Tracking System class.
=end

require 'fileutils'

require 'kagemai/config'
require 'kagemai/project'
require 'kagemai/reporttype'
require 'kagemai/util'
require 'kagemai/sharedfile'

require 'kagemai/mail/mailer'

require 'kagemai/filestore'
require 'kagemai/xmlstore'
# require 'kagemai/pstore'

module Kagemai
  class BTS
    ATTIC_DIR = '_attic'
    DEFAULT_DB_MANAGER_CLASS = XMLFileStore
    
    def initialize(project_dir)
      @project_dir = Util.untaint_path(project_dir)
      
      Config[:stores] = [Kagemai::XMLFileStore]
      
      if Config[:enable_postgres] then
        require 'kagemai/pgstore'
        require 'kagemai/pgstore3'
        require 'kagemai/pgstore4'
        Config[:stores] << Kagemai::PostgresStore  # obsolete
        Config[:stores] << Kagemai::PostgresStore3 # obsolete
        Config[:stores] << Kagemai::PostgresStore4
      end      
      
      if Config[:enable_mssql] then
        if /^Provider=/ =~ Config[:mssql_dsn] then
          require 'kagemai/mssqlstore3'
          require 'kagemai/mssqlstore4'
          Config[:stores] << Kagemai::MSSqlStore3 # obsolete
          Config[:stores] << Kagemai::MSSqlStore4
        else
          require 'kagemai/mssqlstore'
          require 'kagemai/odbcstore4'
          Config[:stores] << Kagemai::MSSqlStore # obsolete
          Config[:stores] << Kagemai::ODBCStore3 # obsolete
          Config[:stores] << Kagemai::ODBCStore4
        end
      end
      
      if Config[:enable_mysql] then
        require 'kagemai/mysqlstore'
        require 'kagemai/mysqlstore2'
        require 'kagemai/mysqlstore3'
        require 'kagemai/mysqlstore4'
        Config[:stores] << Kagemai::MySQLStore  # obsolete
        Config[:stores] << Kagemai::MySQLStore2 # obsolete
        Config[:stores] << Kagemai::MySQLStore3 # obsolete
        Config[:stores] << Kagemai::MySQLStore4
      end      
      
      # set default mailer
      mailer_class = eval(Config[:mailer].untaint)
      Mailer.set_mailer(mailer_class.new)
    end
    
    def create_project(options)
      # make project dir
      id = options.fetch('id')
      dir = "#{@project_dir}/#{id}"
      FileUtils.mkpath(dir)
      FileUtils.chmod2(Config[:dir_mode], dir)
      
      # make cache_dir
      cache_dir = "#{dir}/cache"
      FileUtils.mkpath(cache_dir)
      FileUtils.chmod2(Config[:dir_mode], cache_dir)
      
      begin
        # save configurations
        save_project_config(id, options)
        
        # copy ReportType
        lang = options.fetch('lang')
        template = options.fetch('template')
        template_base = "#{template_dir(lang)}/#{template}"
        rtype_template_filename = "#{template_base}/reporttype.xml"
        rtype_filename = "#{dir}/reporttype.xml"
        FileUtils.copy(rtype_template_filename, rtype_filename)
        FileUtils.chmod2(Config[:file_mode], rtype_filename)
        
        # copy message bundle
        mb_template_filename = "#{template_base}/#{Config[:message_bundle_name]}"
        mb_filename = "#{dir}/#{Config[:message_bundle_name]}"
        if File.exist?("#{template_base}/messages") then
          FileUtils.copy(mb_template_filename, mb_filename)
          FileUtils.chmod2(Config[:file_mode], mb_filename)
        end
        
        # copy message bundle
        mb_template_filename = "#{template_base}/#{Config[:message_bundle_name]}"
        mb_filename = "#{dir}/#{Config[:message_bundle_name]}"
        if File.exist?("#{template_base}/messages") then
          File.copy(mb_template_filename, mb_filename)
          File.chmod2(Config[:file_mode], mb_filename)
        end
        
        # copy  templates
        template_dir = "#{dir}/template"
        Dir.mkdir(template_dir)
        FileUtils.chmod2(Config[:dir_mode], template_dir)
        if File.exist?("#{template_base}/template") then
          Dir.glob("#{template_base}/template/[A-Za-z0-9]*") do |path|
            next if path =~ /CVS$/
            path = Util.untaint_path(path)
            dist = "#{dir}/template/#{File.basename(path)}"
            FileUtils.copy(path, dist)
            FileUtils.chmod2(Config[:file_mode], dist)
          end
        end
        
        # copy scripts
        script_dir = "#{dir}/script"
        Dir.mkdir(script_dir)
        FileUtils.chmod2(Config[:dir_mode], script_dir)
        if File.exist?("#{template_base}/script") then
          Dir.glob("#{template_base}/script/[A-Za-z0-9]*") do |path|
            next if path =~ /CVS$/
            path = Util.untaint_path(path)
            dist = "#{dir}/script/#{File.basename(path)}"
            FileUtils.copy(path, dist)
            FileUtils.chmod2(Config[:file_mode], dist)
          end
        end
        
        # make include file for mail interface
        mail_include_file = "#{dir}/include"
        mailif = "#{Config.root}/bin/mailif.rb"
        mailif_opt = "#{id} -c #{Config.config_file}"
        File.open(mail_include_file, 'wb') do |file|
          file.puts %Q!"|#{$RUBY_BINARY} #{mailif} #{mailif_opt}"!
        end
        FileUtils.chmod2(0644, mail_include_file)
        
        # make mail spool
        mail_spool_dir = "#{dir}/mail"
        Dir.mkdir(mail_spool_dir)
        FileUtils.chmod2(Config[:dir_mode], mail_spool_dir)
        
        # make cache dir
        cache_dir = "#{dir}/cache"
        unless File.exist?(cache_dir) then
          Dir.mkdir(cache_dir)
          File.chmod2(Config[:dir_mode], cache_dir)
        end
        
        # initialize store
        report_type = ReportType.load(rtype_filename)
        store = validate_store(options.fetch('store'))
        charset = options.fetch('charset')
        store.create(dir, id, report_type, charset)
      rescue
        Dir.delete_dir(dir)
        raise
      end
      
      open_project(id)
    end
    
    def save_project_config(id, options)
      Project.save_config(@project_dir, id, options)
    end
    
    def convert_store(id, charset, report_type, 
                      old_db_manager_class, new_db_manager_class)
      return if new_db_manager_class == old_db_manager_class

      source_dir = "#{@project_dir}/#{id}"
      begin
        work_dir = "#{@project_dir}/_#{id}"
        work_db_manager_class = DEFAULT_DB_MANAGER_CLASS
        
        work_db_manager = nil
        attachment_info_map = {}
        
        if old_db_manager_class != work_db_manager_class then
          FileUtils.makedirs(work_dir)
          work_db_manager_class.create(work_dir, id, report_type, charset)
          work_db_manager = work_db_manager_class.new(work_dir, id, report_type, charset)
          
          db_manager = old_db_manager_class.new(source_dir, id, report_type, charset)
          
          seq_map = {}
          db_manager.each_attachment do |attachment, seq|
            info = Store::FileInfo.new("unknowon", attachment.stat.size)
            seq_map[seq] = work_db_manager.store_attachment(attachment, info)
          end
          
          db_manager.each(report_type) do |report|
            report.each do |m| 
              m.each do |etype, etype_id, etype_name, value|
                if etype.kind_of?(FileElementType) then
                  m.element(etype_id).each do |fileinfo|
                    fileinfo.seq = seq_map[fileinfo.seq]
                    attachment_info_map[fileinfo.seq] = fileinfo.dup
                  end
                end
              end
              m.modified = true
            end
            work_db_manager.store_with_id(report)
          end
          
          db_manager.close()
        else
          work_db_manager = old_db_manager_class.new(source_dir, id, report_type, charset)
          
          work_db_manager.each(report_type) do |report|
            report.each do |m| 
              m.each do |etype, etype_id, etype_name, value|
                if etype.kind_of?(FileElementType) then
                  m.element(etype_id).each do |fileinfo|
                    attachment_info_map[fileinfo.seq] = fileinfo.dup
                  end
                end
              end
            end
          end
          
        end
        
        new_db_manager_class.create(source_dir, id, report_type, charset)
        db_manager = new_db_manager_class.new(source_dir, id, report_type, charset)
        
        seq_map = {}
        work_db_manager.each_attachment do |attachment, seq|
          seq_map[seq] = db_manager.store_attachment(attachment, attachment_info_map[seq])
        end
        
        db_manager.transaction {
          work_db_manager.each(report_type) do |report|
            report.each do |m| 
              m.each do |etype, etype_id, etype_name, value|
                if etype.kind_of?(FileElementType) then
                  m.element(etype_id).each do |fileinfo|
                    fileinfo.seq = seq_map[fileinfo.seq]
                  end
                end
              end
              m.modified = true
            end
            db_manager.store_with_id(report)
          end
        }
      rescue Exception
        begin
          new_db_manager_class.destroy(work_dir, id)
        rescue Exception
          # ignore
          Logger.debug("BTS", $!)
          Logger.debug("BTS", $@)
        end
        raise
      ensure
        begin
          if old_db_manager_class != work_db_manager_class then
            work_db_manager_class.destroy(work_dir, id)
            Dir.delete_dir(work_dir)
          end
        rescue Exception
          # ignore
          Logger.debug("BTS", $!)
          Logger.debug("BTS", $@)
        end
      end

      sleep(1)
      old_db_manager_class.destroy(source_dir, id)
    end
    
    def delete_project(id, delete_all)
      project = open_project(id)
      path = "#{@project_dir}/#{project.id}"
      del_name = "#{attic_dir()}/#{project.id}"
      
      if delete_all then
        project.db_manager_class.destroy(path, id)
        Dir.delete_dir(path)
      else
        FileUtils.makedirs(attic_dir())
        del_base_name = del_name
        
        del_count = 1
        while File.exist?(del_name) do
          del_name = del_base_name + ".old.#{del_count}"
          del_count += 1
        end
        File.rename(path, del_name)
      end
      Thread.current[:Project] = nil
      
      [project, del_name]
    end
    
    def attic_dir()
      "#{@project_dir}/#{ATTIC_DIR}"
    end
    
    def open_project(id)
      Logger.debug('BTS', "open_project: id = #{id.inspect}")
      Project.open(@project_dir, id)
    end
    
    def each_project(&block)
      projects = []
      Dir.glob("#{@project_dir}/[A-Za-z0-9]*") do |path|
        path.untaint
        next if path =~ /CVS$/  # ignore CVS directory
        next if File.file?(path)
        id = File.basename(path)
        projects << Project.open(@project_dir, id)
      end
      projects.sort(){|a, b| a.name <=> b.name}.each(&block)
    ensure
      Thread.current[:Project] = nil
      lang = Thread.current[:CGIApplication].lang
      MessageBundle.open(Config[:resource_dir], lang, Config[:message_bundle_name])
    end
    
    def invalidate_cache()
      Dir.glob("#{@project_dir}/[A-Za-z0-9]*/cache/*.compile") do |path|
        path.untaint
        File.unlink path
      end
    end
    
    def count_project()
      n = 0
      each_project() { n += 1 }
      n
    end
    
    def exist_project?(id)
      path = "#{@project_dir}/#{id}"
      File.exist?(path) && File.directory?(path)
    end
    
    def each_store(&block)
      Config[:stores].each(&block)
    end
    
    def count_store()
      Config[:stores].select{|s| !s.obsolete?}.size
    end
    
    def validate_store(store_name)
      store_class = nil
      each_store do |store|
        if store.to_s == store_name then
          return store
        end
      end
      unless store_class then
        raise ParameterError, "Invalid Store class name - #{store_name}"
      end
    end
    
    def each_template(lang, &block)
      templates = []
      
      Dir.glob("#{template_dir(lang)}/[A-Za-z0-9]*") do |path|
        next if path =~ /CVS$/  # ignore CVS directory
        next if path =~ /#{Config[:default_template_dir]}$/ # ignore default template dir
        
        Logger.debug('BTS', "each_template: path = #{path}")
        
        rt_file = Util.untaint_path("#{path}/reporttype.xml")
        if File.exists?(rt_file) then
          templates << ReportType.load(rt_file)
        end
      end
      templates.each(&block)
    end
    
    def count_template(lang)
      n = 0
      each_template(lang){ n += 1 }
      n
    end
    
    private
    def template_dir(lang)
      "#{Config[:resource_dir]}/#{lang}/template"
    end
  end

end
