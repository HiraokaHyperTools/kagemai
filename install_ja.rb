#!/usr/bin/ruby -Ke
=begin
  Kagemai install script (Japanese-EUC version).

  usage: ruby install_ja.rb [previous-install-logfile]

  $Id: install_ja.rb 472 2008-02-29 18:05:30Z fukuoka $
=end

# ���󥹥ȡ���� Revision number
$revision = '$Revision: 472 $'.sub(/^\$Revisio.: (\d.+) \$$/, '\1')

### �ǡ�������¸����ǥ��쥯�ȥ�ʤɤ� user �� group��
### ���ꤷ�ʤ����ˤϡ������ȥ����Ȥ��Ƥ�������
# $user = 'kagemai'
$group = 'kagemai'

## .htaccess �򥳥ԡ����뤫�ɤ���
$setup_htaccess = true

### ���󥹥ȡ����������

# ��������Τ�ɥ������
$root_dir = '/usr/local/kagemai'      

# CGI �䥹�����륷����
$html_dir = '/var/www/html/kagemai' 

# �ץ������ȤΥǡ������
$data_dir = '/var/lib/kagemai'

# �ѥ���ɥե�����
$passwd_dir = '/etc/kagemai'            

# ���󥹥ȡ���Υ�
$install_logfile = "#{$data_dir}/install.log" 

$bin_dir = "#{$root_dir}/bin"  # �桼�ƥ���ƥ�������ץ�
$lib_dir = "#{$root_dir}/lib"  # ���������
$doc_dir = "#{$root_dir}/doc"  # �ɥ������
$etc_dir = "#{$root_dir}"      # README �� MRTG ������ե�����ʤ�
$resource_dir = "#{$root_dir}/resource" # �ƥ�ץ졼�ȡ���å������꥽����

$html_i_dir       = "#{$root_dir}/html"    # CGI �䥹�����륷���ȡʥ��ԡ��ѡ�

$user_passwd_file  = "#{$passwd_dir}/user.passwd"  # �桼���Υѥ���ɥե�����
$admin_passwd_file = "#{$passwd_dir}/admin.passwd" # �����ԤΥѥ���ɥե�����

$project_dir     = "#{$data_dir}/project"     # �ץ������ȤΥǡ���
$mailif_logfile  = "#{$data_dir}/mailif.log"  # mailif.rb ���ѥ��ե�����
$tmp_dir         = "#{$project_dir}/_tmp"     # ����å���ʤɤΰ���ե�����

$config_file = "#{$html_dir}/kagemai.conf" # ����ե�����


###########################################################################
## �������鲼�ϡ����̤��Խ�����ɬ�פϤ���ޤ���

require 'fileutils'
require 'digest/md5'

## �䤤��碌
def query(msg, default)
  print "#{msg} [#{default ? "Y/n" : "y/N"}]: "
  $stdout.flush
  ans = gets.to_s.strip!
  ans.empty? ? default : (/^[Yy].*/ =~ ans) != nil
end

## ����Υ��󥹥ȡ�������ɤ߹���
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

## uid, gid �μ���
$uid = $gid = -1
begin
  require 'etc.so'
  $uid = Etc.getpwnam($user).uid unless $user.to_s.empty?
  $gid = Etc.getgrnam($group).gid unless $group.to_s.empty?
rescue LoadError
  # ignore
end

## �ǡ����ѥǥ��쥯�ȥ�/�ե�����Υ⡼��
$dir_mode = 02775
$file_mode = 0664
if $uid != -1 && $gid == -1 then
  $dir_mode  = 0755
  $file_mode = 0644
end

## �ǥ��쥯�ȥ�κ���
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

## ���󥹥ȡ�����ե�����κ���
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

## �ե������ digest �η׻�
def digest(filename)
  src = File.open(filename) {|file| file.read}
  digest = Digest::MD5::hexdigest(src)
end

## �ե�����Υ��ԡ�
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

  # ���󥹥ȡ������Ʊ���ե����뤬¸�ߤ��ơ�
  # ����Υ��󥹥ȡ��뤫���ѹ�����Ƥ���ʤ顢�Хå����åפ���
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

## ������ץȥե����빹���ؿ�
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

## ruby �Υѥ��ν񤭴���
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

## ����¾�� setup �ν񤭴���
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

## ���ԡ������ե�����ι���������digest ��׻����ƥ��˽�
$cfiles.each do |name|
  mtime = File.stat(name).mtime
  digest = digest(name)
  $logfile.puts "$ifiles['#{name}'] = [Time.at(#{mtime.to_i}), '#{digest}']"
end

if $backup.size > 0 then
  puts 
  puts "�ʲ��Υե�����ϡ�����Υ��󥹥ȡ������깹������Ƥ��뤿�ᡢ"
  puts "��ĥ�� .bak ��Ĥ�����¸���ޤ�����"
  $backup.each do |name|
    puts " #{name}"
  end
end
$stdout.flush

###########################################################################
## kagemai.conf ������

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
## dot.htaccess ������

unless $setup_htaccess then
  File.unlink $files['html']['dot.htaccess'][1]
  exit
end
$stdout.flush

## dot.htaccess �ν񤭴���
htaccess = [$files['html']['dot.htaccess'][1], $files['html_i']['dot.htaccess'][1]]
htaccess.each do |file|
  update_file(file, %r!/etc/kagemai/user\.passwd!, $user_passwd_file)
  update_file(file, %r!/etc/kagemai/admin\.passwd!, $admin_passwd_file)
end
$stdout.flush

## $html_dir �� dot.htaccess �� .htaccess �� rename
from = $files['html']['dot.htaccess'][1]
to = "#{File.dirname(from)}/.htaccess"
unless File.exist?(to) then
  File.rename(from, to)
end
$stdout.flush

## �ѥ���ɥե�����κ���
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
