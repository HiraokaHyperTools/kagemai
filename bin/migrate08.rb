#!/usr/bin/ruby -wKe

=begin
  migrate.rb - 0.7.x から 0.8 へのデータ変換

  Copyright(C) 2003 FUKUOKA Tomoyuki.

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

  $Id: migrate08.rb 528 2008-03-07 13:59:22Z fukuoka $
=end

## NOTE:
##  migrate.rb でプロジェクトを作成したあとに、プロジェクトディレクトリなどを
##  chown する必要があるかもしれない。

# 影舞 0.8 の場所
kagemai_root = File.dirname(File.dirname(File.expand_path(__FILE__))).untaint # setup
config_file  = "#{kagemai_root}/kagemai.conf" # setup

# 影舞 0.7 の global.rb がある場所
old_lib = "" # setup

if old_lib.empty? then
  puts "影舞 0.7 のパスを old_lib に設定してください。"
  exit
end

# 作業ディレクトリ
work_dir = "/tmp/kagemai_migrate_#{Process.pid}" # setup

require 'cgi'    # for CGI::escape, CGI::unescape
require 'fileutils'

# 再帰的なディレクトリの削除
def Dir.remove_dir(dir)
  Dir.foreach(dir) do |path|
    next if path == '.' || path == '..'
    path = dir + '/' + path
    path.untaint
    if FileTest.directory?(path)
      Dir.delete_dir(path)
    else
      File.unlink(path)
    end
  end
  Dir.rmdir(dir)
end

# 0.7 の１つのプロジェクトからデータを抽出
def extract_old_single(project, work_dir)
  puts "extracting #{project.id}(#{project.data.size} reports)"

  project_dir = "#{work_dir}/#{project.id}"
  Dir.mkdir(project_dir)

  File.open("#{work_dir}/#{project.id}/config", 'w') do |file|
    config = %w[
      name desc states default_state priorities default_priority
      categories admin_address notify_addresses post_address
      user_auth_req template_dir css_url subject_tag_figure
    ]
    config.each do |name|
      file.puts "#{name} = #{project.send(name).inspect}"
    end
  end

  File.open("#{project_dir}/size", 'w') do |file|
    file.print project.data.size
  end

  project.each_with_index do |article, i|
    if i % 50 == 0 then
      print '.'; $stdout.flush
    end

    article_dir = "#{project_dir}/#{article.id}"
    Dir.mkdir(article_dir)
    File.open("#{article_dir}/size", 'w') {|file| file.print article.size}

    n = 0
    article.each do |message|
      n += 1
      attributes = %w(from notify state priority categories time)

      File.open("#{article_dir}/#{n}", 'w') do |file|
        file.puts "subject = '#{article.subject}'"
        attributes.each do |attr|
          value = message.send(attr)
          if value.respond_to?('join') then
            value = value.join(',')
          end
          file.puts "#{attr} = '#{value}'"
        end
        body = CGI::escape(message.body)
        file.puts "body = '#{body}'"
      end
    end
  end

  puts
end

# 0.7 のプロジェクトを列挙して抽出
def extract_old(work_dir)
  puts "OLD VERSION = #{Kagemai::Version}"
  
  Dir.glob(Global::ProjectRootDir + '/[A-z]*' + Tracker::INFO_SUFFIX).each do |filename|
    project_id = File.basename(filename, Tracker::INFO_SUFFIX);
    Tracker.open_project(project_id) do |project|
      extract_old_single(project, work_dir)
    end
  end

  puts
end

# 0.8 のプロジェクトの作成
def create_project(project_id, size, work_dir)
  config_src = "#{work_dir}/#{project_id}/config"

  store = 'Kagemai::XMLFileStore'
  template = 'old'

  name = desc = states = default_state = priorities = default_priority = nil
  categories = admin_address = notify_addresses = post_address = nil
  user_auth_req = template_dir = css_url = subject_tag_figure = nil
  File.open(config_src){|file| eval(file.read)}
    
  top_page_opt = {
    "list"        => size < 500, 
    "count"       => true, 
    "search_form" => false, 
    "id_form"     => true,
    "keyword_search_form" => true
  }

  config = {
    'id'       => project_id,
    'lang'     => 'ja',
    'charset'  => 'EUC-JP',
    'template' => 'old',
    'store'    => store,
    'name'              => name,
    'description'       => desc,
    'admin_address'     => admin_address,
    'post_address'      => post_address,
    'notify_addresses'  => notify_addresses,
    'subject_id_figure' => subject_tag_figure,
    'fold_column'       => 68,
    'css_url'           => 'kagemai.css',
    'top_page_options'  => top_page_opt
  }

  bts = BTS.new(Kagemai::Config[:project_dir])
  project = bts.create_project(config)


  # ReportType のカスタマイズ
  etypes = {
    'status'     => [states, default_state],
    'priority'   => [priorities, default_priority],
    'categories' => [categories, '']
  }
  
  etypes.each do |name, value|
    etype = project.report_type[name]
    choices = value[0]
    default = value[1]

    new_choices = []
    choices.each do |c|
      c_opt = {'id' => c, 'show_topics' => true}
      choice = etype.find{|i| i.id == c}
      choice = SelectElementType::Choice.new(c_opt) unless choice
      new_choices << choice
    end
    etype.set_choices(new_choices)

    etype['default'] = default
    etype['allow_guest'] = !user_auth_req if name != 'categories'
    project.change_element_type(etype)
  end

  project
end

# 0.7 から抽出したメッセージから Message オブジェクトを作成
def new_message(report_type, report_dir, n)
  message = Message.new(report_type)

  File.open("#{report_dir}/#{n}") do |file|
    from = subject = state = priority = categories = body = time = notify = nil
    eval(file.read)

    message['email'] = from
    message['title'] = subject
    message['status'] = state
    message['priority'] = priority
    message['categories'] = categories.gsub(/,/, ",\n")
    message['body'] = CGI::unescape(body)
    message.set_option('email_notification', notify)
    message.time = Time.parsedate(time)
  end

  message
end

def migrate_single(project_id, work_dir)
  puts "migrate #{project_id}"

  size_src = "#{work_dir}/#{project_id}/size"
  data_dir = "#{work_dir}/#{project_id}"

  size = File.open(size_src){|file| eval(file.read)}
  project = create_project(project_id, size, work_dir)

  1.upto(size) do |i|
    report_dir = "#{data_dir}/#{i}"
    size = File.open("#{report_dir}/size"){|file| eval(file.read)}

    if i % 50 == 0 then
      print '.'; $stdout.flush
    end
    
    project.transaction do
      # 最初のメッセージをレポートとして追加
      message = new_message(project.report_type, report_dir, 1)
      report = project.new_report2(message)

      # 残りをメッセージとして追加
      2.upto(size) do |i|
        message = new_message(project.report_type, report_dir, i)
        project.add_message2(report.id, message)
      end
    end
  end

  puts
end

def migrate(work_dir)
  puts "NEW VERSION = #{Kagemai::VERSION} (#{Kagemai::CODENAME})"

  Dir.glob(work_dir + '/[A-Za-z0-9]*').each do |filename|
    project_id = File.basename(filename)
    migrate_single(project_id, work_dir)
  end
end

Dir.mkdir(work_dir)

fork {
  $:.unshift(old_lib)

  require 'global'
  require 'kagemai'
  require 'tracker'

  extract_old(work_dir)
}
Process.wait

begin
  $:.unshift("#{kagemai_root}/lib")

  require 'kagemai/config'
  Kagemai::Config.initialize(kagemai_root, config_file)

  require 'kagemai/kagemai'
  require 'kagemai/bts'
  require 'kagemai/project'
  require 'kagemai/message_bundle'
  require 'kagemai/util'
  include Kagemai

  MessageBundle.open(Kagemai::Config[:resource_dir], 
                     'ja', 
                     Kagemai::Config[:message_bundle_name])

  migrate(work_dir)
ensure
  Dir.remove_dir(work_dir)
end
