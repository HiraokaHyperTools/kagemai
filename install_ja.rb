#!/usr/bin/ruby -Ke
=begin
  Kagemai install script (Japanese-EUC version).

  usage: ruby install_ja.rb [previous-install-logfile]

  $Id: install_ja.rb 472 2008-02-29 18:05:30Z fukuoka $
=end

# インストーラの Revision number
$revision = '$Revision: 472 $'.sub(/^\$Revisio.: (\d.+) \$$/, '\1')

### データを保存するディレクトリなどの user と group。
### 設定しない場合には、コメントアウトしてください
# $user = 'kagemai'
$group = 'kagemai'

## .htaccess をコピーするかどうか
$setup_htaccess = true

### インストール先の設定

# 影舞の本体やドキュメント
$root_dir = '/usr/local/kagemai'      

# CGI やスタイルシート
$html_dir = '/var/www/html/kagemai' 

# プロジェクトのデータやログ
$data_dir = '/var/lib/kagemai'

# パスワードファイル
$passwd_dir = '/etc/kagemai'            

# インストールのログ
$install_logfile = "#{$data_dir}/install.log" 

$bin_dir = "#{$root_dir}/bin"  # ユーティリティスクリプト
$lib_dir = "#{$root_dir}/lib"  # 影舞の本体
$doc_dir = "#{$root_dir}/doc"  # ドキュメント
$etc_dir = "#{$root_dir}"      # README や MRTG の設定ファイルなど
$resource_dir = "#{$root_dir}/resource" # テンプレート、メッセージリソース

$html_i_dir       = "#{$root_dir}/html"    # CGI やスタイルシート（コピー用）

$user_passwd_file  = "#{$passwd_dir}/user.passwd"  # ユーザのパスワードファイル
$admin_passwd_file = "#{$passwd_dir}/admin.passwd" # 管理者のパスワードファイル

$project_dir     = "#{$data_dir}/project"     # プロジェクトのデータ
$mailif_logfile  = "#{$data_dir}/mailif.log"  # mailif.rb の用ログファイル
$tmp_dir         = "#{$project_dir}/_tmp"     # キャッシュなどの一時ファイル

$config_file = "#{$html_dir}/kagemai.conf" # 設定ファイル


###########################################################################
## ここから下は、普通は編集する必要はありません

require 'fileutils'
require 'digest/md5'

## 問い合わせ
def query(msg, default)
  print "#{msg} [#{default ? "Y/n" : "y/N"}]: "
  $stdout.flush
  ans = gets.to_s.strip!
  ans.empty? ? default : (/^[Yy].*/ =~ ans) != nil
end

## 前回のインストールログの読み込み
if ARGV.size == 1 then
  $install_logfile = ARGV.shift
end

$ifiles = {}
if File.exist?($install_logfile) then
  msg = "A previous installation log file was found.  Shall I use the same settings as before?"
  if query(msg, true) then
    src = File.open($install_logfile){|file| file.read}
    eval(src)
  end
end
$html_summary_dir = "#{$html_dir}/summary" # for summary PNG file

## uid, gid の取得
$uid = $gid = -1
begin
  require 'etc.so'
  $uid = Etc.getpwnam($user).uid unless $user.to_s.empty?
  $gid = Etc.getgrnam($group).gid unless $group.to_s.empty?
rescue LoadError
  # ignore
end

## データ用ディレクトリ/ファイルのモード
$dir_mode = 02775
$file_mode = 0664
if $uid != -1 && $gid == -1 then
  $dir_mode  = 0755
  $file_mode = 0644
end

## ディレクトリの作成
dirs = %w(
  root_dir
  html_dir data_dir passwd_dir bin_dir lib_dir doc_dir resource_dir
  etc_dir html_summary_dir html_i_dir project_dir
)

dirs.each do |name|
  dir = eval("$#{name}")
  FileUtils.mkpath(dir)
  File.chown($uid, $gid, dir)
end
File.chmod($dir_mode, $data_dir)
File.chmod($dir_mode, $project_dir)
File.chmod($dir_mode, $html_summary_dir)

$ex_lib_dir = $lib_dir

## インストールログファイルの作成
$logfile = File.open($install_logfile, 'w')
$logfile.puts "## KAGEMAI install log"
$logfile.puts "## #{Time.now}"
$logfile.puts 

$logfile.puts "revision = '#{$revision}'"
$logfile.puts 

$logfile.puts "$user = '#{$user}'"
$logfile.puts "$group = '#{$group}'"
$logfile.puts

$logfile.puts "$setup_htaccess = #{$setup_htaccess}"
$logfile.puts

dirs << 'ex_lib_dir'
dirs.each do |name|
  dir = eval("$#{name}")
  $logfile.puts "$%-13s = '%s'" % [name, dir]
end
$logfile.puts

files = %w(user_passwd_file admin_passwd_file mailif_logfile config_file)
files.each do |name|
  $logfile.puts "$%-18s = '%s'" % [name, eval("$#{name}")]
end
$logfile.puts

## ファイルの digest の計算
def digest(filename)
  src = File.open(filename) {|file| file.read}
  digest = Digest::MD5::hexdigest(src)
end

## ファイルのコピー
$backup = []
$files = {}
$cfiles = []
def copy(category, filename)
  dir = eval("$#{category}_dir")
  raise "category error: $#{category}_dir is nil" if dir.to_s.empty?

  to = "#{dir}/#{filename}"
  if category != 'etc' then
    to = "#{dir}/#{filename.sub(/^.+?\//, '')}"
  end

  unless File.exist?(File.dirname(to)) then
    FileUtils.mkpath(File.dirname(to))
  end

  # インストール先に同じファイルが存在して、
  # 前回のインストールから変更されているなら、バックアップを作る
  if File.exist?(to) && $ifiles.has_key?(to) then
    mtime, digest = $ifiles[to]
    if mtime != File.stat(to) && digest != digest(to) then
      File.rename(to, to + '.bak')
      $backup << to
    end
  end

  FileUtils.copy(filename, to, {:verbose => true})

  stat = File.stat(filename)
  File.chmod(stat.mode, to)
  File.utime(stat.atime, stat.mtime, to)

  $cfiles << to

  unless $files.has_key?(category) then
    $files[category] = {}
  end
  $files[category][File.basename(filename)] = [filename, to]
end


category = 'etc'
IO.foreach('MANIFEST') do |line|
  line.strip!
  next if line.empty?

  if /\[(.+)\]/ =~ line then
    category = $1
    puts 
    puts "[#{category}]"
    $stdout.flush
    next
  end
  
  copy(category, line)
  copy('html_i', line) if category == 'html'
  $stdout.flush
  $stderr.flush
end

## スクリプトファイル更新関数
def update_file(filename, regexp, replace)
  stat = File.stat(filename)

  src = File.open(filename){|file| file.read}
  
  File.open(filename, 'w') do |file|
    file.puts src.sub(regexp, replace)
  end

  File.chmod(stat.mode, filename)
  File.utime(stat.atime, stat.mtime, filename)
end
$stdout.flush

## ruby のパスの書き換え
require 'rbconfig'
ruby_binary = "#{Config::CONFIG['bindir']}/#{Config::CONFIG['ruby_install_name']}"
if RUBY_PLATFORM =~ /mswin32/ then
  ruby_binary.gsub!(/\//, '\\')
end

puts
puts "Update ruby path to '#{ruby_binary}': "
$stdout.flush

bin_files = []
['bin', 'html', 'html_i'].each do |category|
  $files[category].each do |k, v|
    next unless /\.(cgi|fcgi|rb)$/ =~ k
    from, to = v
    bin_files << to
  end
end

bin_files.each do |file|
  puts "  #{file}"
  update_file(file, /^\#!.+?$/m, "#!#{ruby_binary} -Ke")
end
$stdout.flush

## その他の setup の書き換え
puts ""
puts "Update kagemai paths:"
$stdout.flush
['bin', 'html'].each do |category|
  $files[category].each do |k, v|
    next unless /\.(cgi|fcgi|rb)$/ =~ k
    file = v[1]
    puts "  #{file}"
    update_file(file, /^kagemai_root\s*=.*\# setup$/, "kagemai_root = '#{$root_dir}'")
    update_file(file, /^config_file\s*=.*\# setup$/, "config_file = '#{$config_file}'")
    update_file(file, /^\$LOGFILE\s*=.*\# setup$/, "$LOGFILE = '#{$mailif_logfile}'")
  end
end
$stdout.flush

## コピーしたファイルの更新日時、digest を計算してログに書く
$cfiles.each do |name|
  mtime = File.stat(name).mtime
  digest = digest(name)
  $logfile.puts "$ifiles['#{name}'] = [Time.at(#{mtime.to_i}), '#{digest}']"
end

if $backup.size > 0 then
  puts 
  puts "以下のファイルは、前回のインストール時より更新されているため、"
  puts "拡張子 .bak をつけて保存しました。"
  $backup.each do |name|
    puts " #{name}"
  end
end
$stdout.flush

###########################################################################
## kagemai.conf の設定

unless File.exist?($config_file) then
  File.open($config_file, 'w') do |file|
    file.puts "module Kagemai"
    file.puts "  Config[:project_dir] = '#{$project_dir}'"
    file.puts "  Config[:tmp_dir] = '#{$tmp_dir}'"
    file.puts "end"
  end
  File.open($config_file + "~", 'w') do |file|
    # nothing
  end
  File.chown($uid, $gid, $config_file)
  File.chmod($file_mode, $config_file)
  File.chown($uid, $gid, $config_file + "~")
  File.chmod($file_mode, $config_file + "~")
end

###########################################################################
## dot.htaccess の設定

unless $setup_htaccess then
  File.unlink $files['html']['dot.htaccess'][1]
  exit
end
$stdout.flush

## dot.htaccess の書き換え
htaccess = [$files['html']['dot.htaccess'][1], $files['html_i']['dot.htaccess'][1]]
htaccess.each do |file|
  update_file(file, %r!/etc/kagemai/user\.passwd!, $user_passwd_file)
  update_file(file, %r!/etc/kagemai/admin\.passwd!, $admin_passwd_file)
end
$stdout.flush

## $html_dir の dot.htaccess を .htaccess に rename
from = $files['html']['dot.htaccess'][1]
to = "#{File.dirname(from)}/.htaccess"
unless File.exist?(to) then
  File.rename(from, to)
end
$stdout.flush

## パスワードファイルの作成
puts ""
[$user_passwd_file, $admin_passwd_file].each do |passwd|
  unless File.exist?(passwd) then
    if query("Create '#{passwd}'?", true) then
      print 'name: '
      $stdout.flush
      name = gets.strip
      system "htpasswd -c #{passwd} #{name}" unless name == ''
    end
  end
end
$stdout.flush
