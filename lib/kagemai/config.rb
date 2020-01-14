=begin
  config.rb -- KAGEMAI configuration file.
=end

require 'rbconfig'
require 'kagemai/error'

$RUBY_BINARY = "#{Config::CONFIG['bindir']}/#{Config::CONFIG['ruby_install_name']}"

module Kagemai
  CONFIG_VAR_NAMES = %w(
    maintenance_mode
    language charset
    home_url
    base_url
    action_dir 
    project_dir resource_dir
    mailer
    smtp_server smtp_port
    mail_command
    default_template_dir
    message_bundle_name
    default_store
    default_template
    subject_id_figure
    fold_column
    use_filter
    css_url
    max_attachment_size
    use_html_cache
    guest_mode_cgi user_mode_cgi admin_mode_cgi
    use_javascript
    allow_mail_body_command
    search_form_method
    pretty_html
    enable_postgres postgres_host postgres_port postgres_user postgres_dbname
    postgres_pass postgres_opts
    enable_mssql mssql_dsn mssql_user mssql_pass
    enable_mysql mysql_host mysql_port mysql_user mysql_pass mysql_dbname
    enable_gdchart
    gd_font
    gd_charset
    rss_feed_title
    captcha_font
    captcha_char_length
  )
  
  DEFAULT_CONFIG = {
    :maintenance_mode => false,

    :language => 'ja',       # default language.
    :charset  => 'EUC-JP',   # default charset.
    
    :home_url => 'http://www.example.org/',   # setup
    :base_url => 'http://localhost/kagemai/', # setup
    
    # mailer
    :mailer => 'Kagemai::SmtpMailer',
    
    # SMTP server address
    :smtp_server => 'localhost' , # setup
    :smtp_port   => 25,           # setup
    
    # default mail command for MailCommandMailer
    :mail_command => '/usr/bin/mail', # setup
    
    # default template dir
    :default_template_dir => '_default',
    
    # default message bundle file
    :message_bundle_name => 'messages',
    
    # デフォルトの保存形式
    :default_store => 'Kagemai::XMLFileStore',
    
    # デフォルトのテンプレート
    :default_template => 'simple',
    
    # メールのサブジェクトの ID の桁数
    :subject_id_figure => 4,
    
    # テキストの折り返し桁数
    :fold_column => 64,

    # フィルタの使用
    :use_filter => false,
    
    # 添付ファイルの制限サイズ [KBytes]。0 以下なら制限なし。
    :max_attachment_size => 1500,

    # HTML キャッシュを使うかどうか
    :use_html_cache => true,
    
    # *.cgi の名前
    :guest_mode_cgi => 'guest.cgi',
    :user_mode_cgi  => 'user.cgi',
    :admin_mode_cgi => 'admin.cgi',
        
    # スタイルシートの URL
    :css_url => 'kagemai.css',
    
    # Javascript の利用
    :use_javascript => true,
    
    # メールでのメッセージ要素の値の変更の可否
    :allow_mail_body_command => true,
    
    # 検索時フォームの METHOD の値
    :search_form_method => "GET",

    # HTML の整形を行うかどうか
    :pretty_html => false,
    
    # PostgreSQL
    :enable_postgres => false,     # setup
    :postgres_host => '/tmp',      # setup
    :postgres_port => '',          # setup
    :postgres_user => 'kagemai',   # setup
    :postgres_pass => '',          # setup
    :postgres_opts => '',          # setup
    :postgres_dbname => 'kagemai',
    
    # MS SQL Server
    :enable_mssql => false,
    :mssql_dsn    => 'Provider=SQLOLEDB;Server=.\SQLEXPRESS;Database=kagemai',
    :mssql_user   => 'kagemai',
    :mssql_pass   => '',
    
    # MySQL
    :enable_mysql => false,
    :mysql_host   => 'localhost',
    :mysql_port   => '3306',
    :mysql_user   => 'kagemai',
    :mysql_pass   => '',
    :mysql_dbname => 'kagemai',
    
    # GDChart for summary
    :enable_gdchart => false,
    :gd_font => '/usr/share/fonts/japanese/TrueType/sazanami-gothic.ttf',
    :gd_charset  => 'EUC-JP',
    
    # title for RSS-all
    :rss_feed_title => 'Bug Tracking System Kagemai',
    
    # font for captcha
    :captcha_font => '/usr/share/fonts/japanese/TrueType/sazanami-gothic.ttf',
    
    # character length for captcha.
    # 0 means no captcha
    :captcha_char_length => 0,
  }

  module Config
    def self.initialize(root, config_file)
      @@root = root
      @@config_file = config_file
      
      hash = {
        :action_dir   => "#{root}/lib/kagemai/cgi/action",
        :project_dir  => "#{root}/project",
        :tmp_dir      => "#{root}/project/_tmp",
        :resource_dir => "#{root}/resource",
        
        # mode of dir and file
        :dir_mode  => 02775,
        :file_mode => 0664,
        
        :session_expire => 30, # 30 minutes
      }
      hash.update(DEFAULT_CONFIG)
      
      Thread.current[:Config] = hash
      
      if !config_file.to_s.empty? && File.exists?(config_file) then
        load config_file
      end
    end
    
    def self.root() @@root; end
    def self.config_file() @@config_file; end
    
    def self.[](key)
      hash = Thread.current[:Config]
      raise ConfigError, "key not found: #{key}" unless hash.has_key?(key)
      hash[key]
    end
    
    def self.[]=(key, value)
      Thread.current[:Config][key] = value
    end
  end
  
  # MIME_TYPES
  MIME_TYPES = [
    'text/plain',
    'text/html',
    'image/jpeg',
    'image/png'
  ]

  TOP_PAGE_OPTIONS = {
    'count'               => true,
    'list'                => true,
    'id_form'             => true,
    'keyword_search_form' => true,
    'search_form'         => false
  }

end
