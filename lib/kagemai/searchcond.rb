=begin
  searchcond.rb - represent search conditions

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

require 'kagemai/message_bundle'
require 'date'

module Kagemai
  class NullSearchCond
    def initialize(value)
      @value = value
    end
    
    def match(message)
      @value
    end
    
    def to_sql(sql_op, &col_name)
      sql_op[@value == true]
    end

    def to_sql3(sql_op, &proc)
      sql_op[@value == true]
    end

    def to_s(report_type)
      @value.to_s
    end

    def size
      1
    end
  end

  class SearchInclude
    def initialize(eid, word, case_insensitive = false)
      @eid = eid
      @word = word
      @case_insensitive = case_insensitive
    end
    
    def match(message)
      unless @case_insensitive then
        message[@eid].include?(@word)
      else
        pattern = case_insensitive_re_pattern(@word)
        SearchRegexp.new(@eid, pattern).match(message)
      end
    end
    
    def to_sql(sql_op, &col_name)
      quoted = @word.gsub(/(['%_])/) {|s| '\\' + s}
      
      unless @case_insensitive then
        "#{col_name.call(@eid)} like '%#{quoted}%'"
      else
        pattern = case_insensitive_re_pattern(@word)
        SearchRegexp.new(@eid, pattern).to_sql(sql_op, &col_name)
      end
    end

    def to_sql3(sql_op, &proc)
      unless @case_insensitive then
        col, quoted = proc.call(@eid, '%' + @word + '%')
        "#{col} like #{quoted}"
      else
        pattern = case_insensitive_re_pattern(@word)
        SearchRegexp.new(@eid, pattern).to_sql3(sql_op, &proc)
      end
    end
    
    Zenkaku_Alpha = '£Á£Â£Ã£Ä£Å£Æ£Ç£È£É£Ê£Ë£Ì£Í£Î£Ï£Ð£Ñ£Ò£Ó£Ô£Õ£Ö£×£Ø£Ù£Ú' 
    Zenkaku_alpha = '£á£â£ã£ä£å£æ£ç£è£é£ê£ë£ì£í£î£ï£ð£ñ£ò£ó£ô£õ£ö£÷£ø£ù£ú'
    
    Hankaku_Alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 
    Hankaku_alpha = 'abcdefghijklmnopqrstuvwxyz'
    
    Zenkaku_ach = Zenkaku_Alpha + Zenkaku_alpha
    Hankaku_ach = Hankaku_Alpha + Hankaku_alpha
    
    Zenkaku_num = '£°£±£²£³£´£µ£¶£·£¸£¹'
    Hankaku_num = '0123456789'
    
    Zenkaku_sym = '¡ª¡÷¡ô¡ð¡ó¡°¡õ¡ö¡Ê¡Ë¡Ý¡á¡Î¡Ï¡ï¡¨¡Ç¡¢¡£¡¿¡²¡Ü¡Ð¡Ñ¡Ã¡§¡É¡ã¡ä¡©¡®¡Á'
    Hankaku_sym = '!@#$%^&*()-=[]\\;\',./_+{}|:"<>?`~'
    
    Zenkaku = Zenkaku_num + Zenkaku_sym
    Hankaku = Hankaku_num + Hankaku_sym
    
    def case_insensitive_re_pattern_alpha(alphabet_char)
      up       = alphabet_char.upcase
      down     = alphabet_char.downcase
      zen_up   = Zenkaku_ach[Hankaku_ach.index(up) * 2, 2]
      zen_down = Zenkaku_ach[Hankaku_ach.index(down) * 2, 2]
      "[#{up}#{down}#{zen_up}#{zen_down}]"
    end
    
    def case_insensitive_re_pattern(str)
      $KCODE = 'EUC-JP'
      pattern = ''
      
      str.scan(/./) {|ch|
        case ch          
        when /[A-Za-z]/ then
          pattern += case_insensitive_re_pattern_alpha(ch)
        when /[£Á-£Ú£á-£ú]/ then
          i = Zenkaku_ach.index(ch) / 2
          han = Hankaku_ach[i, 1]
          pattern += case_insensitive_re_pattern_alpha(han)
        when /[#{Regexp.quote(Hankaku)}]/ then
          i = Hankaku.index(ch) * 2
          zen = Zenkaku[i, 2]
          han = Regexp.quote(ch)
          pattern += "[#{han}#{zen}]"
        when /[#{Zenkaku}]/ then
          i = Zenkaku.index(ch) / 2
          han = Regexp.quote(Hankaku[i, 1])
          pattern += "[#{han}#{ch}]"
        else
          pattern += Regexp.quote(ch)
        end
      }
      pattern
    end
    
    def to_s(report_type)
      MessageBundle[:search_cond_include] % [report_type[@eid].name, @word]
    end
    
    def size
      1
    end
  end

  class SearchEqual
    def initialize(eid, word)
      @eid = eid
      @word = word
    end

    def match(message)
      message[@eid] == @word
    end

    def to_sql(sql_op, &col_name)
      quoted = @word.gsub(/(['%_])/) {|s| '\\' + s}
      "#{col_name.call(@eid)} = '#{quoted}'"
    end

    def to_sql3(sql_op, &proc)
      col, quoted = proc.call(@eid, @word)
      "#{col} = #{quoted}"
    end
    
    def to_s(report_type)
      MessageBundle[:search_cond_equal] % [report_type[@eid].name, @word]
    end

    def size
      1
    end
  end

  class SearchRegexp
    def initialize(eid, word)
      @eid = eid
      @word = word
    end
    
    def match(message)
      (Regexp.new(@word) =~ message[@eid]) != nil
    end
    
    def to_sql(sql_op, &col_name)
      quoted = @word.gsub(/'/) {|s| '\\' + s}
      "#{col_name.call(@eid)} #{sql_op['regexp']} '#{quoted}'"
    end

    def to_sql3(sql_op, &proc)
      col, quoted = proc.call(@eid, @word)
      "#{col} #{sql_op['regexp']} #{quoted}"
    end
    
    def to_s(report_type)
      "/#{@word}/ =~ #{report_type[@eid].name}" 
    end
    
    def size
      1
    end
  end

  class SearchKeywordType
    class << self
      include Enumerable
    end

    def initialize(id)
      @id = id
      @name = MessageBundle["search_keyword_#{@id}".intern]
    end
    attr_reader :id, :name

    def self.each(&block)
      types = [
        SearchKeywordType.new('include_all'),
        SearchKeywordType.new('include_any'),
        SearchKeywordType.new('not_include_all'),
        SearchKeywordType.new('not_include_any'),
        SearchKeywordType.new('regexp')
      ]
      types.each(&block)
    end
    
    def size
      1
    end
  end

  class SearchMultiSelectType
    class << self
      include Enumerable
    end
    
    def initialize(id)
      @id = id
      @name = MessageBundle["search_multi_#{@id}".intern]
    end
    attr_reader :id, :name
    
    def self.each(&block)
      types = [
        SearchMultiSelectType.new('equal'),
        SearchMultiSelectType.new('include_all'),
        SearchMultiSelectType.new('include_any'),
      ]
      types.each(&block)
    end
    
    def size
      1
    end
  end

  class SearchCondPeriod
    def initialize(pbegin, pend)
      @pbegin = pbegin
      @pend = pend
    end

    def match(message)
      @pbegin <= message.time && message.time <= @pend
    end

    def to_sql(sql_op, &col_name)
      "('#{@pbegin.format}' <= create_time and create_time <= '#{@pend.format}')"
    end
    
    def to_sql3(sql_op, &col_name)
      "('#{@pbegin.format}' <= create_time and create_time <= '#{@pend.format}')"
    end

    def to_s(report_type)
      "('#{@pbegin.format}' <= create_time && create_time <= '#{@pend.format}')"
    end

    def size
      1
    end
  end

  class SearchPeriodType
    class << self
      include Enumerable
    end

    def initialize(id)
      @id = id
      @name = MessageBundle["search_period_#{@id}".intern]
    end
    attr_reader :id, :name

    def self.each(&block)
      types = [
        SearchPeriodType.new('all'),
        SearchPeriodType.new('last_year'),
        SearchPeriodType.new('last_month'),
        SearchPeriodType.new('last_week'),
        SearchPeriodType.new('last_day'),
        SearchPeriodType.new('other'),
      ]
      types.each(&block)
    end

    def condition(pbegin, pend)
      case @id
      when 'all'
        return nil
      when 'last_year'
        pbegin = time_of_day(356)
        pend = Time.now
      when 'last_month'
        pbegin = time_of_day(30)
        pend = Time.now
      when 'last_week'
        pbegin = time_of_day(7)
        pend = Time.now
      when 'last_day'
        pbegin = Time.now - (24 * 60 * 60)
        pend = Time.now
      when 'other'
        # nothing to do.
      end
      SearchCondPeriod.new(pbegin, pend)
    end

    private
    def time_of_day(n_days_ago = 0)
      date = Date.today - n_days_ago
      Time.local(date.year, date.month, date.day)
    end
  end

  class BinarySearchCond
    def initialize(*children)
      @children = children
      @children ||= []
    end

    def push(child)
      @children.push(child)
    end

    def match(message)
      if @children.size == 0 then
        return false
      end

      result = @children[0].match(message)
      1.upto(@children.size - 1) do |i|
        result = match_op(result, @children[i].match(message))
      end
      result
    end
    
    def to_sql(sql_ops, &col_name)
      if @children.size == 0 then
        return nil
      end
      
      sql = @children.collect{|child| child.to_sql(sql_ops, &col_name)}.join(sql_op())
      "(#{sql})"
    end
    
    def to_sql3(sql_ops, &proc)
      if @children.size == 0 then
        return nil
      end
      
      sql = @children.collect{|child| child.to_sql3(sql_ops, &proc)}.join(sql_op())
      "(#{sql})"
    end
    
    def to_s(report_type)
      '(' + @children.collect{|condition| condition.to_s(report_type)}.join("#{op_str()}\n") + ')'
    end

    def size
      @children.size - 1
    end
  end

  class SearchCondOr < BinarySearchCond
    alias :or :push

    def initialize(*children)
      super
      if @children.size == 0 then
        push(NullSearchCond.new(false))
      end
    end

    def match_op(a, b)
      a || b
    end

    def sql_op
      ' or '
    end

    def op_str
      ' || '
    end
  end

  class SearchCondAnd < BinarySearchCond
    def initialize(*children)
      super
      if @children.size == 0 then
        push(NullSearchCond.new(true))
      end
    end

    alias :and :push

    def match_op(a, b)
      a && b
    end

    def sql_op
      ' and '
    end

    def op_str
      ' && '
    end
  end

  class SearchCondNot
    def initialize(condition)
      @condition = condition
    end

    def match(message)
      !@condition.match(message)
    end

    def to_sql(sql_op, &col_name)
      "(not #{@condition.to_sql(sql_op, &col_name)})"
    end

    def to_sql3(sql_op, &proc)
      "(not #{@condition.to_sql(sql_op, &proc)})"
    end

    def to_s(report_type)
      "!(#{@condition.to_s(report_type)})"
    end
  end

end
