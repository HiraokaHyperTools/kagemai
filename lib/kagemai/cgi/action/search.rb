=begin
  SearchReport

  Copyright(C) 2002-2005 FUKUOKA Tomoyuki.

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

require 'kagemai/cgi/action'
require 'kagemai/util'
require 'kagemai/searchcond'
require 'kagemai/message_bundle'

module Kagemai
  class SearchReport < Action
    def self.name()
      'search'
    end
    Action::add_action(self)
    
    SEARCH_ACTION_MAP = {
      'make_form' => :make_form,
      'keyword'   => :keyword_search,
      'search'    => :search,
      'attr'      => :attr_search
    }

    def execute()
      init_project()

      @limit = @cgi.get_param('limit', 50).to_i
      @offset = @cgi.get_param('offset', '0').to_i
      @order = @cgi.get_param('order', 'report_id')

      action_map = Hash.new(:invalid_search_type).update(SEARCH_ACTION_MAP)
      send(action_map[@cgi.get_param('search_type', 'make_form')])
    end

    def make_form()
      param = {:mode => @mode, :project => @project}
      body = eval_template('search.rhtml', param)
      ActionResult.new(MessageBundle[:title_search_form], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end

    def keyword_search()
      keyword = @cgi.get_param('keyword')

      search_elements = Hash.new(false)
      if keyword then
        case_insensitive = @cgi.get_param('case_insensitive') == 'on'
        
        condition = SearchCondOr.new
        @project.report_type.each do |etype|
          if @cgi.get_param(etype.id, '').upcase == 'ON' then
            search_elements[etype.id] = true
            condition.or(SearchInclude.new(etype.id, keyword, case_insensitive))
          end
        end
      else
        keyword   = ""
        condition = NullSearchCond.new(true)
      end  
      
      attr_cond = NullSearchCond.new(true)

      result = @project.search(attr_cond, condition, true, @limit, @offset, @order)
      result.params = {}
      @cgi.each {|k, v| result.params[k] = v.to_s.escape_u}

      param = {
        :mode     => @mode,
        :project  => @project,
        :keyword  => keyword,
        :result   => result,
        :case_insensitive => case_insensitive,
        :search_elements => search_elements
      }
      body = eval_template('keyword_search_result.rhtml', param)
      ActionResult.new(MessageBundle[:title_search_result], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
    end

    def search()
      case op = @cgi.get_param('search_op')
      when 'and_all'
        and_op = true
        cond_attr  = SearchCondAnd.new
        cond_other = SearchCondAnd.new
      when 'or_all'
        and_op = false
        cond_attr  = SearchCondOr.new
        cond_other = SearchCondOr.new
      else
        raise ParameterError, "Invalid search_op. search_op = #{op.inspect}"
      end

      @project.report_type.each do |etype|
        cond = etype.make_search_cond(@cgi)
        (etype.report_attr ? cond_attr : cond_other).push(cond) if cond
      end

      period = {}
      ['b_year', 'b_month', 'b_day', 'e_year', 'e_month', 'e_day'].each do |k|
        v = @cgi.get_param(k)
        if v then
          period[k] = v
        else
          raise ParameterError, "No parameter: #{k.inspect}"
        end
      end
      period_begin = Time.parsedate("#{period['b_year']}/#{period['b_month']}/#{period['b_day']}")
      period_end   = Time.parsedate("#{period['e_year']}/#{period['e_month']}/#{period['e_day']}")
      period_end += (24 * 60 * 60 - 1) # 指定した日の最後の時刻まで

      if period_begin > period_end then
        # TODO: raise parameter error
      end

      pt = @cgi.get_param('period_type')
      period_type = SearchPeriodType.find{|t| t.id == pt}
      unless period_type then
        raise ParameterError, "Invalid period_type: period_type = #{pt.inspect}"
      end
      period_condition = period_type.condition(period_begin, period_end)
      cond_other.push(period_condition) if period_condition
      
      as_csv = false
      limit  = @limit
      if @cgi.get_param('as_csv', 'off').downcase == 'on' then
        as_csv = true
        limit  = @project.size
      end
      
      as_csv_file = false
      limit  = @limit
      if @cgi.get_param('as_csv_file', 'off').downcase == 'on' then
        as_csv_file = true
        limit  = @project.size
      end
      
      result = @project.search(cond_attr, cond_other, and_op, limit, @offset, @order)
      result.params = {}
      @cgi.each {|k, v| result.params[k] = v.to_s.escape_u}
      
      param = {
        :mode       => @mode,
        :project    => @project,
        :result     => result,
        :cond_attr  => cond_attr,
        :cond_other => cond_other,
        :and_op     => and_op,
        :period_begin => period_begin,
        :period_end   => period_end
      }
      
      unless as_csv || as_csv_file then
        body = eval_template('search_result.rhtml', param)
        ActionResult.new(MessageBundle[:title_search_result], 
                         header(), 
                         body, 
                         footer(), 
                         @css_url, 
                         @lang,
                         @charset)
      else
        header = @project.report_type.collect{|etype| etype.report_attr ? etype.name : nil}.compact
        header.unshift('ID')
        header << MessageBundle[:csv_author]
        header << MessageBundle[:csv_ctime]
        header << MessageBundle[:csv_mtime]
        csv = header.collect{|h| "\"#{h}\""}.join(',') + "\r\n"
        
        result.reports.each do |report|
          line = ['"' + report.id.to_s + '"'] 
          report.each_attr do |etype|
            value = report[etype.id].to_s
            line << "\"" + value.gsub(/"/, '""') + "\""
          end
          line << "\"" + report.author.value + "\""
          line << "\"" + report.create_time + "\""
          line << "\"" + report.modify_time + "\""
          csv += line.join(',') + "\r\n"
        end
        
        if as_csv_file then
          csv = csv.tosjis
          header_option = {
            'type' => 'application/octet-stream',
            'charset'=> 'Shift_JIS',
            'Content-Disposition' => 'attachment;filename=SearchResult.csv'
          }
          header = @cgi.header(header_option)
        else
          header = @cgi.header({'type' => 'text/plain', 'charset' => 'EUC-JP'})
        end
        RawActionResult.new(header, csv)
      end
    end

    def attr_search()
      etype = validate_etype(@cgi.get_param('etype'))
      attr = @cgi.get_param(etype.id)
      raise ParameterError, "Invalid Condition: #{etype.id}" if attr.to_s.empty?
      
      cond_attr = etype.make_search_cond(@cgi, 'include_any')
      
      result = @project.search(cond_attr, nil, false, @limit, @offset, @order)
      result.params = {}
      @cgi.each {|k, v| result.params[k] = v.to_s.escape_u}

      param = {
        :mode    => @mode,
        :project => @project,
        :result  => result,
        :etype   => etype,
        :attr    => attr
      }
      body = eval_template('attr_search_result.rhtml', param)
      ActionResult.new(MessageBundle[:title_search_result], 
                       header(), 
                       body, 
                       footer(), 
                       @css_url, 
                       @lang,
                       @charset)
      
    end

    def invalid_search_type()
      search_type = @cgi.get_param('search_type')
      raise ParameterError, "Invalid search type: search_type = #{search_type.inspect}"
    end

    
    def validate_etype(etype_id)
      @project.report_type.each do |etype|
        return etype if etype.id == etype_id
      end
      raise ParameterError, "Invalid Element Type ID: #{etype_id}"
    end

    def self.href(base_url, project_id)
      param = {'action' => name(), 'project' => project_id}
      project_id ? MessageBundle[:action_search_report].href(base_url, param) : nil
    end    
  end
end
