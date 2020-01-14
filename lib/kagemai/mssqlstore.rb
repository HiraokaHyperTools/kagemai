=begin
  MSSqlStore - MS SQL*Server report manager.

  Copyright(C) 2002-2004 FUKUOKA Tomoyuki.
  Copyright(c) 2004 Tajima Akio NCR Japan Ltd.

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

require 'kagemai/store'
require 'kagemai/util'
require 'kagemai/kconv'

require 'tempfile'
require 'win32ole'

module Kagemai
  
  class ElementType;
    def ms_sql_type()
      'varchar(256)'
    end
  end
  
  class TextElementType
    def ms_sql_type()
      'text'
    end
  end

  class ADO
    def initialize(dsn, db, user, pwd, &block)
      @ado = WIN32OLE.new('ADODB.Connection')
      if db.nil?
	conn = dsn
      else
	conn = "dsn=#{dsn};database=#{db.gsub(/-/, '')}"
      end
      @ado.Open(conn, user, pwd)
      if !block.nil?
	begin
	  @ado.beginTrans
	  yield self
	  @ado.commitTrans
	  @ado.close
	rescue
	  @ado.rollbackTrans
	  @ado.close
	  raise
	end
      end
    end

    def close()
      @ado.execute("use master")
      # @ado.close()
    end

    def transaction(&block)
      @ado.beginTrans
      begin
	yield
	@ado.commitTrans
      rescue
	@ado.rollbackTrans
	raise
      end
    end

    def create_database(db)
      dbase = db.gsub(/-/, '')
      begin
	s = "create database #{dbase}"
	@ado.execute(s, nil, 0x80)
      rescue
	puts $!.message if $debug
      end
      @ado.execute("use #{dbase}", nil, 0x80)
    end

    def create_table(name, *cols)
      @ado.execute("create table #{name} (#{cols.join(', ')})", nil, 0x80)
    end

    def select_one(sql)
      r = @ado.execute(sql)
      ret = r.fields(0).value
      r.close
      ret
    end
    
    def select_all(sql, &block)
      r = @ado.execute(sql)
      while !r.eof do
        fields = r.fields
        
        values = {}
        for i in 0...fields.count do
          item = fields.item(i)
          values[item.name] = item.value
        end
        
	yield values
        
	r.moveNext
      end
      r.close
    end
    
    def add_record(tbl)
      rec = WIN32OLE.new('ADODB.RecordSet')
      rec.open(tbl, @ado, 2, 3)
      rec.addNew
      rec
    end

    def open_record(tbl, key = nil)
      if key.nil?
	r = @ado.execute("select * from #{tbl}")
      else
	r = @ado.execute("select * from #{tbl} where id=#{key}")
      end
      r
    end

    def open_record_for_write(tbl, key = nil)
      if key.nil?
	sql = "select * from #{tbl}"
      else
	sql = "select * from #{tbl} where id=#{key}"
      end
      rec = WIN32OLE.new('ADODB.RecordSet')
      rec.open(sql, @ado, 2, 3)
      rec
    end

    def execute(sql)
      @ado.execute(sql, nil, 0x80)
    end

    def create_last_message_view(report_type)
      cols = [
        'messages.report_id', 
        'messages.id', 
        'reports.size', 
        'reports.create_time', 
        'reports.modify_time'
      ]
      report_type.each do |etype|
        cols << "messages.#{etype.id}" if etype.report_attr
      end
      cond = "last_message_id = messages.id"

      query = "select #{cols.join(',')} from reports, messages where #{cond}"

      execute("create view last_messages as #{query}")
    end

    def drop_last_message_view()
      execute('drop view last_messages')
    end

  end

  class MSSqlStore < Store

    include WIN32OLE::VARIANT

    MESSAGE_OPTION_COL_NAME = 'k_options'
    MESSAGE_OPTION_MAX_SIZE = 256
    APPENDCHUNK = 1107
    
    SQL_SEARCH_OP = {
      true     => 'true',
      false    => 'false',
      'regexp' => '~',
    }
    
    def self.obsolete?()
      true
    end
    
    def self.disp_name()
      'old MSSqlStore(obsolete)'
    end
    
    def self.description()
      MessageBundle[:MSSqlStore]
    end

    def self.destroy(dir, project_id)
      ADO.new(Config[:mssql_dsn], 'master',
	      Config[:mssql_user], Config[:mssql_pass]) {|ado|
	ado.execute("drop database #{project_id}")
      }
    end

    def self.create(dir, project_id, report_type, charset)
      ADO.new(Config[:mssql_dsn], nil,
	      Config[:mssql_user], Config[:mssql_pass]) {|ado|
	init_tables(ado, dir, project_id, report_type)
      }
    end

    def self.init_tables(ado, dir, project_id, report_type)
      ado.create_database(project_id)
      ado.create_table('reports', 
		       'id int identity primary key',
		       'size int',
		       'first_message_id int',
		       'last_message_id int',
		       'create_time datetime',
		       'modify_time datetime')

      message_cols = [
	'id int identity primary key',
	'report_id int',
	'create_time datetime',
        "#{MESSAGE_OPTION_COL_NAME} varchar(#{MESSAGE_OPTION_MAX_SIZE})"
      ]
      report_type.each do |etype|
	message_cols << "#{etype.id} #{etype.ms_sql_type}"
      end
        
      ado.create_table('messages', *message_cols)
        
      ado.create_table('attachments',
		       'id int identity primary key',
		       'name varchar(256)',
		       'size integer',
		       'mimetype varchar(128)',
		       'create_time datetime',
		       'data image')
        
      ado.execute("create index rid_index on messages (report_id)")
        
      ado.create_last_message_view(report_type)

    end

    def initialize(dir, project_id, report_type, charset)
      @ado = nil
      @project_id = project_id
    end

    def close()
      @ado.close() unless @ado.nil?
    end
    
    def col_name(etype_id)
      etype_id
    end
    
    def store(report)
      setup_ado
      report.each do |msg|
	next unless msg.modified?
	r = @ado.add_record('messages')
	flds = r.fields
	flds.item('report_id').value = report.id
	flds.item('create_time').value = msg.create_time
	report.type.each do |etype|
	  flds.item(etype.id).value = KKconv::conv(msg[etype.id], KKconv::SJIS, KKconv::EUC)
	end
	flds.item(MESSAGE_OPTION_COL_NAME).value = msg.option_str()
	r.update
	r.close
	msg.modified = false
      end

      sql = "select min(id) from messages where report_id = #{report.id}"
      first_message_id = @ado.select_one(sql)
      sql = "select max(id) from messages where report_id = #{report.id}"
      last_message_id = @ado.select_one(sql)

      r = @ado.open_record_for_write('reports', report.id)
      flds = r.fields
      flds.item('size').value = report.size
      flds.item('create_time').value = report.create_time
      flds.item('modify_time').value = report.modify_time
      flds.item('first_message_id').value = first_message_id
      flds.item('last_message_id').value = last_message_id
      r.update
      r.close
    end

    def store_with_id(report)
      nid = 0
      until nid == report.id do
        nid = next_id()
      end
      store(report)
    end

    def update(report)
      setup_ado
      @ado.execute("delete from messages where report_id = #{report.id}")
      report.each {|message| message.modified = true}
      store(report)
    end

    def load(report_type, id)
      setup_ado
      report = Report.new(report_type, id)
      message_id = 0
      @ado.select_all("select * from messages where report_id = #{id} order by id") do |row|
	message = Message.new(report_type, message_id)
	report_type.each {|etype| 
          str = KKconv::conv(row[etype.id].to_s, KKconv::EUC, KKconv::SJIS)
	  message[etype.id] = str
	}
	message.time = Time.local(*ParseDate.parsedate(row['create_time']))
	message.set_option_str(row[MESSAGE_OPTION_COL_NAME])
	message.modified = false
        
	report.add_message(message)
	message_id += 1
      end
      if message_id == 0 then
	raise ParameterError, MessageBundle[:err_invalid_report_id] % id.to_s
      end
      report
    end

    def size()
      setup_ado
      size = nil
      size = @ado.select_one('select count(id) from reports').to_i        
      Logger.debug('DBI', "size: report count(id) = #{size}")
      size
    end

    def transaction(&block)
      setup_ado
      @ado.transaction{ yield }
    end

    def each(report_type, &block)
      setup_ado
      @ado.select_all('select id from reports') do |row|
	block.call(load(report_type, row['id']))
      end
    end

    def next_id()
      setup_ado
      next_id = nil
      @ado.execute("insert into reports (size) values (0)")
      if self.size > 0
	next_id = @ado.select_one("select max(id) from reports").to_i
	Logger.debug('DBI', "next_id: report max(id) = #{next_id}")
      else
	next_id = 1
      end
      next_id
    end

    def add_element_type(report_type, etype)
      setup_ado
      @ado.execute("alter table messages add #{etype.id} #{etype.ms_sql_type}")
      change_element_type(report_type)
    end
    
    def delete_element_type(report_type, etype_id)
      setup_ado
      @ado.execute("alter table messages drop column #{etype_id}")
      change_element_type(report_type)
    end
    
    def change_element_type(report_type)
      setup_ado
      @ado.drop_last_message_view()
      @ado.create_last_message_view(report_type)
    end

    def search(report_type, cond_attr, cond_other, and_op, limit, offset, order)
      setup_ado
      id = nil
      attr_id = []
      if cond_attr && cond_attr.size > 0 then
        cond_attr_query = KKconv::conv(cond_attr.to_sql(SQL_SEARCH_OP){|eid| col_name(eid)}, KKconv::SJIS, KKconv::EUC)
        cond_attr_query.gsub!(/(false|true)( (or|and) )*/, '')
	if cond_attr_query != ''
	  cond_attr_query = 'where ' + cond_attr_query
	end
        query = "select report_id from last_messages #{cond_attr_query} order by #{order}"
	@ado.select_all(query) do |row|
	  attr_id << row['report_id'].to_i
        end
        id = attr_id
      end

      other_id = []
      if cond_other && cond_other.size > 0 then
        cond_other_query = KKconv::conv(cond_other.to_sql(SQL_SEARCH_OP) {|eid| col_name(eid)}, KKconv::SJIS, KKconv::EUC)
        cond_other_query.gsub!(/(false|true)( (or|and) )*/, '')
	
	if cond_other_query != ''
	  cond_other_query = 'where ' + cond_other_query
	end
        query = "select DISTINCT report_id from messages #{cond_other_query} order by #{order}"
	@ado.select_all(query) do |row|
	  other_id << row['report_id'].to_i
        end

        if id.nil? then
          id = other_id
        else
          id = and_op ? (attr_id & other_id) : (attr_id | other_id)
        end
      end

      if id.nil? then
        # no condition, select all.
        id = []
        query = "select DISTINCT report_id from messages order by report_id"
	@ado.select_all(query) do |row|
	  id << row['report_id'].to_i
        end
      end

      reports = load_dummies(report_type, id[offset, limit])
      Store::SearchResult.new(id.size, limit, offset, reports)
    end

    def load_dummies(report_type, id)

      return [] if id.size == 0
      
      setup_ado
      reports = {}
      cols = 'id,first_message_id,last_message_id,size'

      sql = "select #{cols} from reports where id in (#{id.join(',')}) order by id"
      r_size = {}
      mid = []
      @ado.select_all(sql) do |row|
	rid = row['id'].to_i
	mid << row['first_message_id'].to_i 
	mid << row['last_message_id'].to_i 
	r_size[rid] = row['size']
      end
        
      sql = "select * from messages where id in (#{mid.join(',')}) order by id"
      @ado.select_all(sql) do |row|
	message = Message.new(report_type)
	report_type.each do |etype|
          str = KKconv::conv(row[etype.id].to_s, KKconv::EUC, KKconv::SJIS)
          message[etype.id] = str
	end
	message.time = Time.local(*ParseDate.parsedate(row['create_time']))
	message.modified = false
            
	rid = row['report_id'].to_i
	report = nil
	if reports.has_key?(rid) then
	  report = reports[rid]
	  2.upto(r_size[rid] - 1) do |n| # add dummy messages
	    report.add_message(Message.new(report_type, n))
	  end
	else
	  report = Report.new(report_type, rid)
	  reports[rid] = report
	end
	report.add_message(message)
      end
    
      id.collect{|i| reports[i]}
    end

    def load_dummy(report_type, report_id)
      load_dummies(report_type, [report_id])[0]
    end

    def collect_reports(report_type, attr_id)

      setup_ado
      collection = {}
      
      query = 'select id from reports order by id'

      @ado.select_all(query) do |row|
	report = load_dummy(report_type, row['id'])
	attrs = report[attr_id].to_s
	attrs.split(/,\n/).each { |attr|
	  if collection.has_key?(attr)
	    collection[attr].push(report)
	  else
	    collection[attr] = [report]
	  end
	}
      end

      collection
    end

    def count_reports(report_type, attr_id)
      setup_ado
      counts = Hash.new(0)
      query = "select #{attr_id} from last_messages order by report_id"
      @ado.select_all(query) do |row|
        attrs = KKconv::conv(row[attr_id].to_s, KKconv::EUC, KKconv::SJIS)
	attrs.split(/,\n/).each {|attr| counts[attr] += 1}
      end
      counts
    end

    def store_attachment(attachment, fileinfo)
      setup_ado
      id = -1
      @ado.transaction {
	rec = @ado.add_record('attachments')
	flds = rec.fields
	fn = fileinfo.name
	flds.item('name').value = KKconv::conv(fn, KKconv::SJIS, KKconv::EUC)
	flds.item('size').value = attachment.stat.size
	flds.item('create_time').value = attachment.stat.ctime
	blob = flds.item('data')
	len = 4096
	while (buff = attachment.read(len)) do
	  blob._invoke(APPENDCHUNK, [buff.unpack('C*')], [VT_ARRAY | VT_UI1])
	end
	attachment.close
	rec.update
        rec.close
	id = @ado.select_one('select max(id) from attachments')
      }
      id
    end
    
    def open_attachment(seq_id)
      setup_ado
      rec = @ado.open_record('attachments', seq_id)
      f = read_att(rec)
      rec.close
      f
    end

    def each_attachment()
      setup_ado
      r = @ado.open_record('attachments')
      while !r.eof
	seq = r.fields.item('id').value.to_i
	file = open_attachment(seq)
	begin
	  yield file, seq
	ensure
	  file.close
        end
	r.moveNext
      end
      r.close
    end

    private

    def setup_ado()
      return if !@ado.nil?
      @ado = ADO.new(Config[:mssql_dsn], @project_id, 
		     Config[:mssql_user], Config[:mssql_pass])
    end

    def read_att(rec)
      sz = rec.fields('size').value
      file = Tempfile.new('kagemai_lo_export')
      file.binmode
      buff = rec.fields('data').getChunk(sz)
      file.write(buff.pack('C*'))
      file.seek(0)
      file
    end
  end
end

