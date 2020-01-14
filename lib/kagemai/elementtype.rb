=begin
  ElementType - メッセージが持つ要素の種類を表します
=end

require 'date'
require 'kagemai/message_bundle'

module Kagemai
  class ElementTypeOption
    def initialize(name, default, 
                   dispname = nil, writable = false, depends = nil,
                   description = nil)
      @name = name
      @default = default
      @dispname = dispname ? dispname : name
      @writable = writable
      @depends = depends
      @description = description
    end
    attr_reader :name, :default, :dispname, :writable, :depends
    attr_reader :description

    def parse_value(value)
      value ? value : @default
    end
  end

  class ElementTypeBooleanOption < ElementTypeOption
    def parse_value(value)
      unless value.nil? then
        (value == true || value == 'true' || value == 'on') ? true : false
      else
        @default
      end
    end
  end

  class ElementType
    include Enumerable
    
    def initialize(attr)
      before_init_hook()
      
      @attr = attr.clone

      # check require attr
      ['id'].each do |k|
        raise InitializeError, 
          "Invalid ReportType definition. '#{k}' isn't specified." unless @attr.has_key?(k)
      end
      @id = @attr['id']
      
      # known options
      options = [
        ElementTypeOption.new('name', attr['id']),
        ElementTypeOption.new('default', nil, nil, true),
        ElementTypeOption.new('description', '', nil, true),
      ]
      options += self.class.boolean_options()
      options += self.class.extended_options(attr)
      options << ElementTypeBooleanOption.new('delete', true)

      writable = []
      @defaults = {}
      options.each do |option|
        @attr[option.name]  = option.parse_value(@attr[option.name])
        @defaults[option.name] = option.default
        writable << option.name if option.writable
        define_query_method(option.name) if option.kind_of?(ElementTypeBooleanOption)
      end

      @attr.each do |k, v|
        add_attr(k, v, writable.include?(k))
      end

      after_init_hook()
    end
    attr_reader :boolean_options
    
    def _dump(limit)
      Marshal.dump(@attr)
    end
    
    def self._load(obj)
      ElementType.new(Marshal.load(obj))
    end
        
    # max string-value size
    # nil means unlimited.
    def max_size()
      255
    end
    
    def element_created(element)
      # Element が作られたときに呼ばれる。
      # 要素型固有の動作を要素に加えたいときにオーバーライドする
    end

    def empty_value()
      default()
    end

    def self.default_value()
      'nil'
    end

    def self.extended_options(attr)
      []
    end

    def self.boolean_options()
      bopt = [
        ElementTypeBooleanOption.new('use_cookie', false, 
                                     MessageBundle[:ElementType_opt_use_cookie]),
        ElementTypeBooleanOption.new('email_check', false, 
                                     MessageBundle[:ElementType_opt_email_check]),
        ElementTypeBooleanOption.new('report_attr', false, 
                                     MessageBundle[:ElementType_opt_report_attr]),
        ElementTypeBooleanOption.new('allow_guest', 
                                     false,
                                     MessageBundle[:ElementType_opt_allow_guest], 
                                     false, 
                                     'report_attr'),
        ElementTypeBooleanOption.new('allow_user', 
                                     true,
                                     MessageBundle[:ElementType_opt_allow_user], 
                                     false, 
                                     'report_attr'),
        ElementTypeBooleanOption.new('list_item', false, 
                                     MessageBundle[:ElementType_opt_list_item],
                                     false,
                                     'report_attr'),
        ElementTypeBooleanOption.new('show_header', false, 
                                     MessageBundle[:ElementType_opt_show_header]),
        ElementTypeBooleanOption.new('show_header_line', 
                                     false, 
                                     MessageBundle[:ElementType_opt_show_header_line],
                                     false, 
                                     'show_header'),
        ElementTypeBooleanOption.new('hide_from_guest', 
                                     false, 
                                     MessageBundle[:ElementType_opt_hide_from_guest]),
      ] 

      bopt + extended_boolean_options()
    end

    def self.extended_boolean_options()
      []
    end

    def self.option_names()
      options = extended_options(nil) + 
                boolean_options() + 
                extended_boolean_options()
      options.collect{|opt| opt.name}
    end

    def [](key)
      @attr[key]
    end

    def []=(key, value)
      @attr[key] = value
    end
    
    def required?() self.default == nil end

    def can_delete?() delete?() end
    
    def define_query_method(name)
      eval("def self.#{name}?() @attr['#{name}'] end")
    end

    def add_attr(key, value, writable)
      key = key.dup.untaint
      value = value.untaint
      @attr[key] = value
      eval("def self.#{key}() @attr['#{key}'] end")
      eval("def self.#{key}=(value) @attr['#{key}'] = value end") if writable
    end

    def to_xml(indent)
      params = []
      @attr.each do |key, value|
        next if key == 'description'
        next if value == @defaults[key]
        params << %Q!#{key}="#{value.to_s.escape_h}"! if value != nil
      end
      
      indent = to_a.empty? ? '' : indent
      cindent = to_a.empty? ? '' : indent + indent
      csep    = to_a.empty? ? "" : "\n"

      stag = %Q!<#{tagname} #{params.join(' ')}>! + csep

      each do |child|
        stag += cindent + child.to_xml(cindent) + csep
      end

      stag += cindent + @attr['description'].to_s.strip.escape_h + csep
      stag += indent + "</#{tagname}>"
    end

    def each(&block)
      # no children
    end

    def tagname()
      self.class.tagname()
    end

    def keyword_search?()
      false
    end

    def before_init_hook()  end
    def after_init_hook() end
    protected :before_init_hook, :after_init_hook

    def ==(rhs)
      @attr.each do |k, v|
        return false if v != rhs[k]
      end
      true
    end
  end

  class StringElementType < ElementType
    def self.tagname()
      'string'
    end

    def self.extended_options(attr)
      [
        ElementTypeOption.new('size', '30', MessageBundle[:StringElementType_opt_size]),
      ]
    end

    def keyword_search?()
      true
    end

    def self._load(obj)
      StringElementType.new(Marshal.load(obj))
    end
  end

  class SelectElementType < ElementType
    class Choice < ElementType
      def self.tagname()
        'choice'
      end

      def self.extended_options(attr)
        [
          ElementTypeOption.new('sdesc', attr['id'], nil, true),
          ElementTypeBooleanOption.new('show_topics', 
                                       true, 
                                       MessageBundle[:Choice_opt_show_topics])
        ]
      end

      def self._load(obj)
        Choice.new(Marshal.load(obj))
      end
    end
    
    def self.tagname()
      'select'
    end

    def self.extended_options(attr)
      [
        ElementTypeOption.new('close_by', '', 
                              MessageBundle[:SelectElementType_opt_close_by], 
                              true,
                              nil,
                              MessageBundle[:SelectElementType_opt_close_by_desc])
      ]
    end

    def self.extended_boolean_options()
      [
        ElementTypeBooleanOption.new('show_topics', 
                                     false, 
                                     MessageBundle[:SelectElementType_opt_show_topics], 
                                     false,
                                     'report_attr'),
        ElementTypeBooleanOption.new('radio', 
                                     false, 
                                     MessageBundle[:SelectElementType_opt_radio]),
      ]
    end

    def self.default_value()
      ''
    end
    
    def self.option_names()
      super() + ['choices']
    end
    
    def self._load(str)
      attr, choices = Marshal.load(str)
      SelectElementType.new(Marshal.load(attr), Marshal.load(choices))
    end
    
    def _dump(limit)
      Marshal.dump([Marshal.dump(@attr), Marshal.dump(@choices)])
    end
    
    def initialize(attr, choices = nil)
      @choices = choices
      super(attr)
    end
    
    def after_init_hook()
      @choices = Array.new unless @choices
    end
    
    def add_choice(choice)
      @choices.push(choice)
      @attr['choices'] = @choices.collect{|c| c.id}.join(', ')
    end

    def set_choices(choices)
      @choices = choices
      @attr['choices'] = @choices.collect{|c| c.id}.join(', ')
    end

    def each(&block)
      @choices.each(&block)
    end

    def size()
      @choices.size
    end
    
    def choices2() # for ==()
      @choices
    end
    
    def ==(rhs)
      super && @choices == rhs.choices2
    end
  end
  
  class MultiSelectElementType < SelectElementType
    def self.tagname()
      'multiselect'
    end
    
    def self.extended_boolean_options()
      [
        ElementTypeBooleanOption.new('show_topics', 
                                     false, 
                                     MessageBundle[:MultiSelectElementType_opt_show_topics]),
        ElementTypeBooleanOption.new('checkbox', 
                                     false, 
                                     MessageBundle[:MultiSelectElementType_opt_checkbox])
      ]
    end
    
    def self._load(str)
      attr, choices = Marshal.load(str)
      MultiSelectElementType.new(Marshal.load(attr), Marshal.load(choices))
    end
    
    def _dump(limit)
      Marshal.dump([Marshal.dump(@attr), Marshal.dump(@choices)])
    end
    
    def initialize(attr, choices = nil)
      super(attr, choices)
    end
    
  end

  class TextElementType < ElementType
    def self.tagname()
      'text'
    end

    def self.extended_options(attr)
      [
        ElementTypeOption.new('cols', '70', MessageBundle[:TextElementType_opt_cols]),
        ElementTypeOption.new('rows', '15', MessageBundle[:TextElementType_opt_rows]),
      ]
    end

    def self.extended_boolean_options()
      [
        ElementTypeBooleanOption.new('quote', 
                                     true, 
                                     MessageBundle[:TextElementType_opt_quote]),
        ElementTypeBooleanOption.new('quote_mark', 
                                     true, 
                                     MessageBundle[:TextElementType_opt_quote_mark]),
      ]
    end
    
    def max_size()
      nil
    end
    
    def keyword_search?()
      true
    end

    def self._load(obj)
      TextElementType.new(Marshal.load(obj))
    end
  end

  class BooleanElementType < ElementType
    def initialize(attr)
      attr['default'] = 'off' unless attr.has_key?('default')
      super(attr)
    end
    
    def empty_value()
      'off'
    end
    
    def self.default_value()
      'off'
    end

    def self.tagname()
      'boolean'
    end

    def max_size()
      4
    end

    def self._load(obj)
      BooleanElementType.new(Marshal.load(obj))
    end
  end
  
  class DateElementType < ElementType
    def self.tagname()
      'date'
    end
    
    def self._load(obj)
      DateElementType.new(Marshal.load(obj))
    end
    
    def self.boolean_options()
      bopt = [
        ElementTypeBooleanOption.new('report_attr', false, 
                                     MessageBundle[:ElementType_opt_report_attr]),
        ElementTypeBooleanOption.new('allow_guest', 
                                     false,
                                     MessageBundle[:ElementType_opt_allow_guest], 
                                     false, 
                                     'report_attr'),
        ElementTypeBooleanOption.new('allow_user', 
                                     true,
                                     MessageBundle[:ElementType_opt_allow_user], 
                                     false, 
                                     'report_attr'),
        ElementTypeBooleanOption.new('list_item', false, 
                                     MessageBundle[:ElementType_opt_list_item],
                                     false,
                                     'report_attr'),
        ElementTypeBooleanOption.new('show_header', false, 
                                     MessageBundle[:ElementType_opt_show_header]),
        ElementTypeBooleanOption.new('show_header_line', 
                                     false, 
                                     MessageBundle[:ElementType_opt_show_header_line],
                                     false, 
                                     'show_header'),
        ElementTypeBooleanOption.new('hide_from_guest', 
                                     false, 
                                     MessageBundle[:ElementType_opt_hide_from_guest]),
      ] 

      bopt + extended_boolean_options()
    end
    
    def use_cookie?
      false
    end
    
    def element_created(element)
      class << element
        def value()
          @value.to_s.empty? ? nil : @value
        end
        
        def value=(v)
          if v.nil? || v.kind_of?(String) then
            @value = !v.to_s.empty? ? Date.parse(v) : nil
          elsif v.kind_of?(Date) then
            @value = v
          elsif v.kind_of?(Time) then
            @value = v.to_date
          elsif defined?(DBI) && v.kind_of?(DBI::Date)
            @value = v.to_date
          else
            raise ArgumentError, "unknown class: #{v.class}"
          end
        end
      end
    end
  end
  
  class FileElementType < ElementType
    def self._load(obj)
      FileElementType.new(Marshal.load(obj))
    end

    class FileInfo
      def self.new2(tempfile, mime_type)
        self.new(-1, 
                 tempfile.original_filename, 
                 tempfile.stat.size, 
                 mime_type,
                 '',
                 tempfile.stat.ctime)
      end

      def self.new3(name, mime_type, ctime, file)
        self.new(-1, name, file.size, mime_type, '', ctime)
      end

      def initialize(seq, name, size, mime_type, comment, create_time, discarded = false)
        @seq = seq
        @name = File.basename(name.gsub(/\\/, '/'))
        @size = size
        @mime_type = mime_type
        @comment = comment
        @create_time = create_time
        @discarded = discarded
      end
      attr_accessor :seq;
      attr_reader :name, :size, :mime_type, :create_time
      attr_reader :comment, :discarded

      def to_s
        [@seq, @name, @size, @mime_type, @comment, @create_time.to_i, @discarded].collect{|e|
          e.to_s.gsub(/\\/, '\\').gsub(/,/, '\,')
        }.join(',')
      end

      def self.parse(str)
        escaped = str.gsub(/\\,/, "\000").gsub(/\\/, "\001").split(/,/)
        escaped = escaped.collect {|e| e.gsub(/\;/, ';').gsub(/\000/, ',').gsub(/\001/, '\\')}
        
        seq, name, size, mime_type, comment, ctime, discarded = escaped

        self.new(seq.to_i, name, size.to_i, mime_type, 
                 comment, Time.at(ctime.to_i), discarded == 'true')
      end
    end

    def self.tagname()
      'file'
    end

    def max_size()
      512 # filename and stats
    end

    def element_created(element)
      element.instance_eval {
        @attachments = []
      }

      class << element
        def add_fileinfo(fileinfo)
          @attachments << fileinfo
        end

        def each(&block)
          @attachments.each(&block)
        end

        def at(i)
          @attachments[i]
        end
        alias :[] :at

        def find_fileinfo(seq)
          each do |fileinfo|
            return fileinfo if fileinfo.seq == seq
          end
          nil
        end
        
        def value()
          @attachments.collect{|a| a.to_s.gsub(/;/, "\\;")}.join(';')
        end

        def value=(v)
          escaped = v.gsub(/\\;/, "\000")
          @attachments = escaped.split(/;/).collect{|s| FileInfo.parse(s.gsub(/\000/, ';'))}
        end
      end
    end

  end
end
