=begin
  htmlhelper.rb - レポートの要素の HTML へのレンダリングや
                  フォームの入力フィールドの作成を行います。

  Copyright(C) 2002-2008 FUKUOKA Tomoyuki.

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

require 'kagemai/elementtype'
require 'kagemai/searchcond'
require 'kagemai/util'
require 'kagemai/cgi/attachment_handler'
require 'kagemai/cgi/htmlrenderer'

class Fixnum
  def html_value()
    self.to_s
  end
end

class String
  def html_value()
    self.escape_h
  end

  def href(url, params = nil, klass = nil, tag_params = {}, url_ref = '')
    if params then
      sep = url.include?('?') ? '&' : '?'
      url += sep + params.collect{|name, value| name + '=' + value}.join('&')
    end
    url += url_ref

    tag_params['href'] = url.escape_h
    tag_params['class'] = klass if klass
    tag('a', tag_params)
  end

  def tag(tagname, params = nil)
    tag_params = ''
    if params then
      pa = params.collect{|name, value| "#{name}=\"#{value}\""}
      tag_params = ' ' + pa.join(' ')
    end
    "<#{tagname}#{tag_params}>#{self}</#{tagname}>"
  end
end

module Kagemai
  class Project
    def url()
      base = CGIApplication.instance.mode.url
      sep  = base.include?('?') ? '&' : '?'
      base + sep + 'project=' + @id
    end

    def href()
      url = CGIApplication.instance.mode.url
      @name.html_value().href(url, {'action' => Top.name, 'project' => @id})
    end
  end

  class Report
    def href(str, params = {}, url_ref = '', klass = nil, tag_params = {}, project = Project.instance)
      url = CGIApplication.instance.mode.url
      
      p = {
        'action' => ViewReport.name, 
        'project' => project.id, 
        'id' => @id.to_s 
      }
      p.update(params)

      str.href(url, p, klass, tag_params, url_ref)
    end
  end

  class Message
    def hide_href(str, hide = true)
      url = CGIApplication.instance.mode.url
      
      p = {
        'action' => HideMessage.name, 
        'project' => Project.instance.id, 
        'id' => report.id.to_s,
        'm' => @id.to_s,
      }
      unless hide then
        p['hide'] = 'false'
      end
      
      str.href(url, p)
    end

    def log_header(line_break = "<br>\n")
      header = ['<span class="date">' + create_time.html_value() + '</span>']
      hlines = []
      @type.each do |etype|
        next unless etype.show_header
        next if etype['hide_from_guest'] && Mode::GUEST.current? 
        html_value = @elements[etype.id].html_value()
        if etype.show_header_line then
          hlines << html_value
        else
          header << html_value
        end
      end
      hlines.unshift(header.join(' | ')).join(line_break)
    end

    def each_fileelement()
      @type.each do |etype|
        if etype.kind_of?(FileElementType)
          yield @elements[etype.id]
        end
      end
    end
  end

  module StringSearchCondHelper
    def html_search(cgi)
      opts ={'size' => '40', 'value' => cgi.get_param(@attr['id'], '').escape_h}
      keyword = input_field('text', @attr['id'], opts) + '<br />'
      
      stype_name = @attr['id'] + '_keyword_type'
      stype = field('select', {'name' => stype_name}) {
        SearchKeywordType.collect {|ktype|
          selected = cgi.get_param(stype_name, '')
          
          oopts = {'value' => ktype.id}
          oopts['selected'] = 'selected' if selected == ktype.id
          
          field('option', oopts) {ktype.name}
        }.join("\n")
      }
      
      case_opt_name = @attr['id'] + '_case_insensitive'
      checked = {}
      if cgi.get_param(@attr['id'] + '_case_insensitive') == 'on' then
        checked['checked'] = 'checked'
      end
      case_opt = input_field('checkbox', case_opt_name, checked)
      case_opt += MessageBundle[:search_cond_case_insensitive]
      
      keyword + "\n" + stype + "<br>\n" + case_opt
    end
    
    def make_search_cond(cgi, default_stype = nil)
      value = cgi.get_param(@attr['id'])
      return nil unless value

      case_opt_name = @attr['id'] + '_case_insensitive'
      case_insensitive = cgi.get_param(case_opt_name) == 'on'

      conditions = value.split(/\s+/).collect{|c| SearchInclude.new(@attr['id'], c, case_insensitive)}

      type_name = @attr['id'] + '_keyword_type'
      case search_type = cgi.get_param(type_name)
      when 'include_all'
        return SearchCondAnd.new(*conditions)
      when 'include_any'
        return SearchCondOr.new(*conditions)
      when 'not_include_all'
        return SearchCondNot.new(SearchCondAnd.new(*conditions))
      when 'not_include_any'
        return SearchCondNot.new(SearchCondOr.new(*conditions))
      when 'regexp'
        return SearchRegexp.new(@attr['id'], value)
      else
        raise ParameterError, "Invalid #{type_name}: #{type_name} = #{serach_type.inspect}"
      end
    end
  end

  class ElementType
    include StringSearchCondHelper
    include HtmlRenderer

    def self.name()
      MessageBundle[self.to_s.intern]
    end

    def self.description()
      MessageBundle[(self.to_s + '_desc').intern]
    end

    def self.top_level?()
      true
    end
    
    def self.order()
      0
    end

    def self.each_children(&block)
      classes = []
      ObjectSpace.each_object(Class) do |class_obj|
        if class_obj.ancestors.include?(self) && class_obj.top_level? then
          next if class_obj == self
          classes << class_obj
        end
      end
      classes.sort{|a, b| a.order() <=> b.order()}.each(&block)
    end

    def self.add_element_renderer(thread, name, renderer)
      if thread[:element_renderer].has_key?(name) then
        thread[:element_renderer][name] << renderer
      else
        thread[:element_renderer][name] = [renderer]
      end
    end

    def html_description()
      description_tag() + @attr['description'].gsub(/\n/m, "<br />\n")
    end

    def html_input(value = '', other = {})
      # TODO: override
      raise NotImplementedError, "at #{self.class}"
    end

    def html_input_with_error(value = '', other = {})
      html_input(value, other)
    end

    def html_value(element, index_item = false)
      if Thread.current[:element_renderer].has_key?(element.id) then
        Thread.current[:element_renderer][element.id].each do |renderer| 
          if !renderer.index_only? || index_item then
            add_temporal_renderer(renderer)
          end
        end
      end

      result = render(element, element.value)

      remove_temporal_renderers()
      
      result
    end

    def do_render(element, value)
      value.to_s.escape_h
    end

    def cookie_id()
      project_id = Thread.current[:Project].id
      (project_id + '_' + @attr['id']).escape_u
    end

    private
    def description_tag()
      '<br />'
    end

    def field(tag, attr = {})
      result = '<' + tag
      attr.each do |k, v|
        begin
          result += ' ' + k + '="' + v + '"'
        rescue => e
          raise RuntimeError, "#{e}: tag = #{tag}, attr = #{attr.inspect}"
        end
      end
      if block_given?
        result + '>' + yield + '</' + tag + '>'
      else
        result + '>'
      end
    end

    def input_field(type, name, others = {})
      attr = {'type' => type, 'name' => name}
      attr.update(others)
      field('input', attr)
    end

    def cookie_value(default = '')
      cgi = CGIApplication.instance.cgi
      cid = cookie_id()
      value = default
      if use_cookie? && cgi.cookies.has_key?(cid)
        value, = cgi.cookies[cid]
        value = value.unescape_u
      end
      
      Logger.debug('Cookie', "cookie_value[#{cid}] = #{value.inspect}")
      
      value
    end
  end
  
  class StringElementType
    include StringSearchCondHelper

    def self.order()
      1
    end

    def html_input(value = cookie_value(), other = {})
      attr = {'value' => value.to_s.escape_h, 'size' => size()}
      attr.update(other)
      input_field('text', @attr['id'], attr)
    end

  end

  class SelectElementType
    class Choice < ElementType
      def self.top_level?()
        false
      end
    end

    def self.order()
      2
    end

    def html_input(value = cookie_value(@attr['default']), other = {})
      if @attr['radio'] then
        field = ''
        @choices.each do |choice|
          attr = {'value' => choice.id.escape_h}
          attr['checked'] = 'checked' if choice.id == value.to_s
          attr.update(other)
          field += input_field('radio', @attr['id'], attr) + choice.id.escape_h + "\n"
        end
        field
      else
        field('select', {'name' => @attr['id']}) {
          choices = "\n"
          @choices.each do |choice|
            attr = {'value' => choice.id.escape_h}
            attr['selected'] = 'selected' if choice.id == value.to_s
            choices += field('option', attr) { choice.id } + "\n"
          end
          choices
        }
      end
    end

    def html_search(cgi)
      value = cgi.get_param(@attr['id'])
      values = split_value(value)

      s_attr = {'name' => @attr['id'], 'size' => (self.size + 1).to_s, 'multiple' => 'multiple'}
      field('select', s_attr) {
        cattr = {'value' => 'any'}
        cattr['selected'] = 'selected' if values.include?('any') || value.to_s.empty?
        choices = field('option', cattr) {
          MessageBundle[:search_select_any] 
        } + "\n"
        
        @choices.each do |choice|
          c_attr = {'value' => choice.id.escape_h}
          c_attr['selected'] = 'selected' if values.include?(choice.id)
          choices += field('option', c_attr){ choice.id } + "\n"
        end
        choices
      }
    end

    def make_search_cond(cgi, default_stype = nil)
      value = cgi.get_param(@attr['id'], 'any')
      values = split_value(value)

      return nil if values.find{|v| v == 'any'}

      condition = SearchCondOr.new
      values.each do |v|
        condition.or(SearchEqual.new(@attr['id'], v))
      end
      condition
    end

    private
    def split_value(value)
      value.to_s.strip.empty? ? [] : value.split(/,\n/m)
    end
  end

  class MultiSelectElementType
    def self.order()
      3
    end

    def do_render(element, value)
      Logger.debug('Action', "MultiSelectElementType#html_value: value = #{value.inspect}")
      values = split_value(value)
      values.empty? ? MessageBundle[:no_values] : values.join(', ').escape_h
    end

    def html_input(value = cookie_value(@attr['default']), other = {})
      selected = split_value(value)

      if @attr['checkbox'] then
        field = ''
        @choices.each do |choice|
          attr = {'value' => choice.id.escape_h}
          attr['checked'] = 'checked' if selected.include?(choice.id)
          attr.update(other)
          field += input_field('checkbox', @attr['id'], attr) + choice.id.escape_h + "\n"
        end
        field
      else
        params = {'name' => @attr['id'], 'multiple' => 'multiple', 'size' => @choices.size.to_s}
        field('select', params) {
          choices = "\n"
          @choices.each do |choice|
            attr = {'value' => choice.id.escape_h}
            attr['selected'] = 'selected' if selected.include?(choice.id)
            choices += field('option', attr) { choice.id } + "\n"
          end
          choices
        }
      end
    end

    def html_search(cgi)
      field_select = super(cgi)

      stype_name = @attr['id'] + '_type'
      stype = field('select', {'name' => stype_name}) {
        SearchMultiSelectType.collect {|ktype|
          selected = cgi.get_param(stype_name, '')
          
          oopts = {'value' => ktype.id}
          oopts['selected'] = 'selected' if selected == ktype.id
          
          field('option', oopts) {ktype.name}
        }.join("\n")
      }

      field_select + "<br>\n" + stype
    end

    def make_search_cond(cgi, default_stype = 'equal')
      value = cgi.get_param(@attr['id'], 'any')
      values = split_value(value)

      return nil if values.find{|v| v == 'any'}
      
      stype_name = @attr['id'] + '_type'
      search_type = cgi.get_param(stype_name, default_stype)
      
      condition = nil
      case search_type
      when 'include_all' then
        condition = SearchInclude.new(@attr['id'], value)
      when 'include_any' then
        condition = SearchCondOr.new
        values.each do |v|
          condition.or(SearchInclude.new(@attr['id'], v))
        end
        condition.or(SearchEqual.new(@attr['id'], value))
      else
        condition = SearchEqual.new(@attr['id'], value)
      end

      condition
    end

  end

  class TextElementType
    include StringSearchCondHelper

    def self.order()
      4
    end

    def html_input(value = '', other = {})
      do_html_input(value, false, other)
    end

    def html_input_with_error(value = '', other = {})
      do_html_input(value, true, other)
    end
    
    def escape_h(element)
      html_value(element, false, true)
    end
    
    def html_value(element, index_item = false, host = false)
      renderers = [UrlRenderer.new, BtsLinkRenderer.new(host), Folding.new]
      renderers.each{|r| add_renderer(r)}
      v = super(element, index_item)
      renderers.each{|r| remove_renderer(r)}
      v.empty? ? v : "<pre>" + v + "</pre>"
    end
    
    def do_render(element, value)
      value.to_s.escape_h
    end

    private
    def do_html_input(value, error, other)
      folding = Folding.new
      attr = {'name' => @attr['id'], 'cols' => cols(), 'rows' => rows()}
      attr.update(other)
      field('textarea', attr) {
        v = @attr['quote'] ? value.to_s : ''
        if @attr['quote_mark'] && !error then
          v = v.empty? ? '' : folding.render(nil, v).quote
        end
        v.escape_h
      }
    end
  end

  class BooleanElementType
    def self.order()
      5
    end

    def html_input(value = @attr['default'], other = {})
      flag = value.to_s.downcase == 'true' || value.to_s.downcase == 'on'
      attr = flag ? {'checked' => 'checked'} : {}
      attr.update(other)
      input_field('checkbox', @attr['id'], attr)
    end

    def description_tag()
      ''
    end
  end

  class FileElementType
    include StringSearchCondHelper
    include AttachmentHandler
    
    def self.order()
      6
    end
    
    def html_input(value = '', other = {})
      mime_types = MIME_TYPES.dup
      mime_types.unshift 'binary'
      mime_types.unshift 'auto'
      mime_type_field = @attr['id'] + '_mime_type'
      
      cgi = CGIApplication.instance.cgi
      selected = cgi.get_param(mime_type_field)
      
      choices = "\n"
      mime_types.each_with_index do |mtype, i|
        if MessageBundle.has_key?("mime_type_#{mtype}".intern) then
          name = MessageBundle["mime_type_#{mtype}".intern]
        else
          name = mtype
        end
        attr = {'value' => mtype}
        attr['selected'] = 'selected' if selected ? mtype == selected : i == 0
        choices += field('option', attr) { name } + "\n"
      end
      
      max_size = Config[:max_attachment_size]
      max_str = max_size > 0 ?  MessageBundle[:m_max_size] % max_size : ''

      result = input_field('file', @attr['id'], other) + "\n"
      result += field('select', {'name' => mime_type_field}) { choices } + max_str
      
      attachment = cgi.cached_attachments[@attr['id']]
      if attachment then
        result = MessageBundle[:cached_attachment] % [attachment.name, attachment.size] + result
      end
      
      result
    end
    
    def file_descs(element)
      message = element.message
      report = message.report
      project = Project.instance
      
      descs = []
      element.each do |attachment|
        name = attachment.name
        mime_type = attachment.mime_type
        size = attachment.size
        params = {
          'action' => Download.name,
          'project' => project.id,
          'r' => report.id.to_s,
          'm' => message.id.to_s,
          'e' => element.id,
          's' => attachment.seq.to_s 
        }
        descs << [name, mime_type, size, params]
      end

      descs
    end

    def html_value(element, index_item = false)
      unless element.value.to_s.empty? then
        url = CGIApplication.instance.mode.url

        values = []
        element.each do |attachment|
          name = attachment.name
          mime_type = attachment.mime_type
          size = attachment.size

          values << "#{name} (#{mime_type}, #{size} bytes)"
        end
        values.join(', ')
      else
        '(no attachment)'
      end
    end
  end
end
