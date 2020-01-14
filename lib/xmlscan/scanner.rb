#
# scanner.rb
#
#   Copyright (C) Ueno Katsuhiro 2000,2001
#
# $Id: scanner.rb,v 1.1.2.7 2001/11/22 18:41:40 katsu Exp $
#

=begin
= xmlscan/scanner.rb

100% pure Ruby XML tokenizer.


== XMLScan

The module for reserving namespace for xmlscan.

=== Module Functions:

--- XMLScan.normalize_linebreaks(str)
        Copies ((|str|)) and replaces all linebreaks to LF ((({"\n"}))).


== XMLScan::Error

The ancestor of all exceptions defined in xmlscan.

=== SuperClass:

* ((<StandardError>))

== XMLScan::ParseError

The exception raised when XML document is not syntactically correct.

=== SuperClass:

* ((<XMLScan::Error>))


== XMLScan::WellFormednessConstraintViolation

The exception raised when XML document is not well-formed.

=== SuperClass:

* ((<XMLScan::Error>))

== XMLScan::WFCViolation

The alias of ((<XMLScan::WellFormednessConstraintViolation>)).


== XMLScan::XMLScanner

The class for tokenizing XML document.
Usually, you should not use this class directly.

=== LIMITATIONS

  * Unlegal characters or character references in XML document may not
    cause errors.
  * Non-Name characters may be included in Name.
  * Avail character encodings depend on Ruby interpreter, thus, for example,
    US-ASCII, ISO-8859-1, UTF-8, EUC-JP, Shift-JIS, and so on.
    UTF-16 is ((*not*)) suported.
  * Internal DTD subset are not supported yet.

=== SuperClass:

* ((<Object>))

=== Class Methods:

--- XMLScan::XMLScanner.new([port])
        Creates a new scanner object. If ((|port|)) is specified,
        ((|port|)) is set as a source object of the scanner object.
        See the description of ((<feed|XMLScan::XMLScanner#feed>))
        method for detail.

=== Methods:

--- XMLScan::XMLScanner#feed(port)
        Sets ((|port|)) as a source object. ((|port|)) is a string,
        an array whose all elements are strings, or an object which
        responds to (({gets})) method. If ((|port|)) is an array,
        each element except last one must be ended with LF ((({"\n"}))).
        The (({gets})) method always have to return a string which
        ends with LF except last line, and returns (({nil}))
        when the object reaches EOF.

--- XMLScan::XMLScanner#parse([port])
        Parses the source. Each specific private method is called
        when the scanner meets each syntactic element.

        The meaning of ((|port|)) is same as
        ((<feed|XMLScan::XMLScanner#feed>)).

--- XMLScan::XMLScanner#step
        Parses the source and stops at a breakable point.
        Returns (({nil})) if parsing is done.

--- XMLScan::XMLScanner#path
        Returns filename which is being parsed.
        Unexpected value should be returned depending on the type of
        the source object.

--- XMLScan::XMLScanner#lineno
        Returns line number where is being parsed.
        Unexpected value should be returned depending on the type of
        the source object.

--- XMLScan::XMLScanner#in_prolog?
        Returns (({true})) when the scanner haven't reach the first
        start tag.

=== Private Methods:

--- XMLScan::XMLScanner#parse_error(msg)
        Called when a parse error is found.
        By default, this method raises ((<XMLScan::ParseError>)).

--- XMLScan::XMLScanner#wellformed_error(msg)
        Called when a well-formedness constraint violation is found.
        By default, this method raises
        ((<XMLScan::WellFormednessConstraintViolation>)).

--- XMLScan::XMLScanner#on_xmldecl(version, encoding, standalone)
        Called when the scanner meets a XML declaration.
--- XMLScan::XMLScanner#on_doctype(root, pubid, sysid)
        Called when the scanner meets a DOCTYPE declaration.
--- XMLScan::XMLScanner#on_comment(str)
        Called when the scanner meets a comment.
--- XMLScan::XMLScanner#on_pi(target, pi)
        Called when the scanner meets a processing instructions.
--- XMLScan::XMLScanner#on_chardata(str)
        Called when the scanner meets character data.
--- XMLScan::XMLScanner#on_cdata(str)
        Called when the scanner meets a CDATA section.
--- XMLScan::XMLScanner#on_etag(name)
        Called when the scanner meets a end tag.
--- XMLScan::XMLScanner#on_stag(name, attr)
        Called when the scanner meets a start tag.
--- XMLScan::XMLScanner#on_emptyelem(name, attr)
        Called when the scanner meets a empty element tag.
--- XMLScan::XMLScanner#on_entityref(ref)
        Called when the scanner meets a general entity reference.
--- XMLScan::XMLScanner#on_charref(code)
        Called when the scanner meets a character reference.
--- XMLScan::XMLScanner#on_entityref_in_attr(ref)
        Called when a general entity reference is found in an attribute
        value.
--- XMLScan::XMLScanner#on_charref_in_attr(code)
        Called when a character reference is found in an attribute value.
--- XMLScan::XMLScanner#on_eof
        Called when the scanner meets EOF.

=end



module XMLScan

  class Error < StandardError ; end
  class ParseError < Error ; end

  class WellFormednessConstraintViolation < Error ; end
  WFCViolation = WellFormednessConstraintViolation



  def self.normalize_linebreaks(str)
    str.gsub(/\r\n?/, "\n")
  end



  class XMLScanner

    class PrivateArray < Array
      private(*superclass.instance_methods(false))
    end


    class PortWrapper

      def gets ; @port.gets ; end
      def lineno ; 0 ; end
      def path ; '-' ; end

      def initialize(port)
        @port = port
        unless port.respond_to? :gets then
          if port.is_a? Array then
            @n = -1
            def self.gets ; @port[@n += 1] ; end
            def self.lineno ; @n + 1 ; end
          else
            def self.gets ; s = @port ; @port = nil ; s ; end
          end
        end
        if port.respond_to? :lineno then
          def self.lineno ; @port.lineno ; end
        end
        if port.respond_to? :path then
          def self.path ; @port.path ; end
        end
      end

      attr_reader :port

      def self.wrap(port)
        if instance_methods(false).find { |i| not port.respond_to? i } then
          new port
        else
          port
        end
      end

    end



    class XMLSource < PrivateArray

      def initialize(port = nil)
        super()
        feed port
      end

      def feed(port)
        port = nil unless port
        @port = PortWrapper.wrap(port)
        @prefetch = nil
        @eof = false
        self
      end

      def eof?
        @eof and empty?
      end

      def abort
        @prefetch = nil
        @eof = true
        clear
        self
      end

      def lineno
        @port.lineno
      end

      def path
        @port.path
      end

      def get_next_line
        if @prefetch then
          ret = @prefetch
          @prefetch = nil
          ret
        elsif @eof then
          []
        else
          src = @port.gets
          unless src then
            @eof = true
            []
          else
            src.chop! if (c = src[-1]) == ?\n or c == ?\r
            src << "\n"   # add a line break, anyway.
            src.split(/(?=>?<|>>)|>/, -1)
          end
        end
      end
      private :get_next_line

      alias orig_pop pop
      private :orig_pop

      def pop
        unless empty? then
          super
        else
          replace get_next_line
          reverse!
          super
        end
      end

      def pop_text
        if empty? then
          s = pop
          s = '>' if s and s.empty?
        else
          s = orig_pop
          s[0,0] = '>' unless (c = s[0]) == ?< or c == ?>
        end
        s
      end

      def tag_start?
        s = last || (@prefetch = get_next_line).first and s[0] == ?<
      end

      def tag_end?
        if empty? then
          s = (@prefetch = get_next_line).first and (s.empty? or s == '>')
        else
          last[0] != ?<
        end
      end

      def delete_tag_end    # delete '>' mark if tag_end?
        if s = last then
          if (c = s[0]) == ?> then
            orig_pop
          else
            c != ?<
          end
        else
          s = (@prefetch=get_next_line).first and (s.empty? or s=='>') and pop
        end
      end

      def pop_in_text  # not tag_start? and pop_text
        s = last || (@prefetch=get_next_line).first and s[0]!=?< and pop_text
      end


      def pop_until_tagdelim  # not tag_start? and not tag_end? and pop
        unless empty? then
          nil
        else
          a = get_next_line
          unless a[1] then   # !a[1] == (a.size < 1)
            a.first
          else
            @prefetch = a
            c = (s = a.first) && s[0] and c != ?< and c != ?> and pop
          end
        end
      end

      def skip_until_tagdelim  # for error recovery
        while pop_until_tagdelim
        end
      end

    end



    def initialize(port = nil)
      @src = XMLSource.new
      @prolog = false
      feed port if port
    end


    def feed(port)
      @src.feed port
      @prolog = true
      self
    end


    attr_reader :prolog
    alias in_prolog? prolog
    undef prolog


    def lineno
      @src.lineno
    end

    def path
      @src.path
    end


    private

    def parse_error(msg)
      raise ParseError, sprintf("%s:%d: %s\n", path, lineno, msg)
    end

    def wellformed_error(msg)
      raise WFCViolation, sprintf("%s:%d: WFC: %s\n", path, lineno, msg)
    end

    def on_xmldecl(version, encoding, standalone)
    end

    def on_doctype(root, pubid, sysid)
    end

    def on_comment(str)
    end

    def on_pi(target, pi)
    end

    def on_chardata(str)
    end

    def on_cdata(str)
    end

    def on_etag(name)
    end

    def on_stag(name, attr)
    end

    def on_emptyelem(name, attr)
    end

    def on_entityref(ref)
    end

    def on_charref(code)
    end

    def on_entityref_in_attr(ref)
      # FIXME: return plain replacement text.
      # FIXME: "WFC: No < in Attribute Values" must be considered here.
      # FIXME: Entity reference archirecture is not fixed yet :-(
      ''
    end

    def on_charref_in_attr(code)
      # FIXME: return string which explains the code.
      ''
    end

    def on_eof
    end


    private

    def scan_content(s)
      begin
        unless /&/ =~ s then
          on_chardata s
        else
          on_chardata s unless (s = $`).empty?
          $'.split(/&/, -1).each { |i|
            unless /[;\s]/ =~ i and $& == ';' then
              s = $`
              unless s then
                parse_error "`&' is not used for entity/character references"
              else
                parse_error "reference to `#{s}' doesn't end with `;'"
                s = nil unless s.empty?
              end
              unless s then
                on_chardata('&' + i)
                next
              end
            end
            ref, i = $`, $'
            if ref[0] != ?\# then
              on_entityref ref
            elsif /\A#(\d+)\z/ =~ ref then
              on_charref $1.to_i
            elsif /\A#x([\dA-Fa-f]+)\z/ =~ ref then
              on_charref $1.hex
            else
              parse_error "invalid character reference `#{ref}'"
            end
            on_chardata i unless i.empty?
          }
        end
      end while s = @src.pop_in_text
    end

    def scan_comment(s)
      s[0,4] = ''  # remove '<!--'
      comm = ''
      until /--/ =~ s
        comm << s
        s = @src.pop_text
        unless s then
          parse_error "unterminated comment meets EOF"
          return on_comment(comm)
        end
      end
      if $'.strip.empty? and @src.delete_tag_end then
        comm << $`
      else
        parse_error "comment is not terminated by `-->'"
        while not @src.delete_tag_end and s = @src.pop_text
          comm << s
        end
      end
      on_comment comm
    end


    def scan_pi(s)
      unless /\A<\?(\S+)(?:\s+|(?=\?\z))/ =~ s then
        parse_error "parse error at `<?'"
        on_chardata s
      else
        target, pi = $1, $'
        until pi[-1] == ?? and @src.delete_tag_end
          s = @src.pop_text
          unless s then
            parse_error "unterminated PI meets EOF"
            return on_pi(target, pi)
          end
          pi << s
        end
        pi.chop!
        on_pi target, pi
      end
    end


    def scan_cdata(s)
      cdata = s
      until cdata[-1] == ?] and cdata[-2] == ?] and @src.delete_tag_end
        s = @src.pop_text
        unless s then
          parse_error "unterminated CDATA section meets EOF"
          return on_chardata(cdata)
        end
        cdata << s
      end
      cdata.chop!.chop!  # remove ']]'
      on_cdata cdata
    end


    def unclosed_tag(t, name = nil)
      name = " `#{name}'" if name
      if @src.tag_start? then
        parse_error "unclosed #{t}#{name} meets another tag"
      else
        parse_error "unclosed #{t}#{name} meets EOF"
      end
    end


    def scan_etag(s)
      s[0,2] = ''  # remove '</'
      if s.empty? then   # </> or </<
        parse_error "parse error at `</'"
        return on_chardata('</')
      elsif /\s/ =~ s then
        s1, s2 = $`, $'
        if s1.empty? then    # </ tag
          parse_error "parse error at `</'"
          return on_chardata('</' + s)
        elsif not s2.strip.empty? then   # </ta g
          parse_error "parse error at `</#{s}'"
          @src.skip_until_tagdelim
        end
        s = s1
      end
      unless @src.delete_tag_end then
        while s2 = @src.pop_until_tagdelim
          unless s2.strip.empty? then   # </ta g
            parse_error "parse error at `</#{s}'"
            @src.skip_until_tagdelim
          end
        end
        unclosed_tag 'end tag', s unless @src.delete_tag_end
      end
      on_etag s
    end



    def scan_attvalue(v)
      v.gsub!(/\s/, ' ')
      v.gsub!(/&([^;\s]+)?;?/) { |m|
        if m[-1] == ?; and (ref = $1) then
          if ref[0] != ?\# then
            on_entityref_in_attr(ref)
          elsif /\A#(\d+)\z/ =~ ref then
            on_charref($1.to_i)
          elsif /\A#x([\dA-Fa-f]+)\z/ =~ ref then
            on_charref($1.hex)
          else
            parse_error "invalid character reference `#{ref}'"
            ''
          end
        else
          parse_error "reference to `#{m}' doesn't end with `;'"
          on_entityref_in_attr(ref).gsub(/\s/, ' ')
        end
      }
    end


    def scan_unquoted_attvalue(v)
      parse_error "attribute value must be quoted"
      scan_attvalue(v)
    end

    def scan_omitted_attvalue(v)
      parse_error "attribute `#{v}' has no value"
      v
    end


    def scan_stag(s)
      unless /(?=[\/\s])/ =~ s then
        name = s
        name[0,1] = ''   # remove '<'
        if name.empty? then    # '<<' or '<>'
          parse_error "parse error at `<'"
          return on_chardata('<' + s)
        end
        unclosed_tag 'start tag', name unless @src.delete_tag_end
        on_stag(name, {})
      else
        name, s2 = $`, $'
        name[0,1] = ''   # remove '<'
        if name.empty? then    # < tag
          parse_error "parse error at `<'"
          return on_chardata(s)
        end
        attr = {}
        method = :on_stag
        attname = nil
        state = 1
        while s = s2 || @src.pop_until_tagdelim
          s2 = nil
          s.scan(/\s+|([^\s\/'"=]+)|('[^']*'?|"[^"]*"?)|(\/\z)|(.)\s*/
                 ) { |key,val,e,delim|
            if key then
              if state == 1 then
                attname = key
                state = 2
              else
                if state == 3 then
                  scan_unquoted_attvalue key
                  key, val = attname, key
                elsif state == 2 then
                  val = scan_omitted_attvalue(key)
                else
                  parse_error "parse error at `#{key}'"
                  key = nil
                end
                if key and attr.key? key then
                  wellformed_error "doubled attribute `#{key}'"
                end
                attr[key] = val if key
                state = 0
              end
            elsif val then
              if state == 3 then
                if attr.key? attname then
                  wellformed_error "doubled attribute `#{attname}'"
                end
                attr[attname] = val
              else
                parse_error "parse error at `#{val[0,1]}'"
              end
              qmark = val.slice!(0)
              if val[-1] == qmark then
                val.chop!
                scan_attvalue val
              else
                scan_attvalue val
                re = /#{qmark.chr}/
                begin
                  s2 = @src.pop_text
                  unless s2 then
                    parse_error "unterminated attribute value meets EOF"
                    break
                  end
                  if s2[0] == ?< then
                    wellformed_error "`<' is found in attribute value"
                  end
                  v, s2 = s2.split(re, 2)
                  scan_attvalue v
                  val << v
                end until s2
              end
              attname = nil
              state = 0
            elsif delim then
              if delim == '=' and state == 2 then
                state = 3
              else
                parse_error "parse error at `#{delim}'"
                state = 0
              end
            elsif e then
              if @src.tag_end? then
                method = :on_emptyelem
              else
                parse_error "parse error at `#{e}'"
              end
            else
              state = 1 if state == 0
            end
          }
        end
        unless state <= 1 then
          if state == 3 then
            parse_error "parse error at `='"
          else # state == 2
            val = scan_omitted_attvalue(attname)
            if attr.key? attname then
              wellformed_error "doubled attribute `#{attname}'"
            end
            attr[attname] = val
          end
        end
        unclosed_tag 'start tag', name unless @src.delete_tag_end
        send method, name, attr
      end
    end



    def scan_bang_tag(s)
      parse_error "parse error at `<!'"
      on_chardata s
    end


    def scan_body(s)
      if (c = s[0]) == ?< then
        if (c = s[1]) == ?/ then
          scan_etag s
        elsif c == ?! then
          if s[2] == ?- and s[3] == ?- then
            scan_comment s
          elsif /\A<!\[CDATA\[/ =~ s then
            scan_cdata $'
          else
            scan_bang_tag s
          end
        elsif c == ?? then
          scan_pi s
        else
          scan_stag s
        end
      else
        scan_content s
      end
    end



    def each_decl_xmldecl(s)
      attname = nil
      state = 1
      begin
        s.scan(/\s+|([^\s\/'"=?]+)|('[^']*'|"[^"]*")|(\?\z)|(.)\s*/
               ) { |key,val,e,delim|
          if key then
            if state == 1 then
              attname = key
              state = 2
            else
              parse_error "unexpected `#{key}' found in XML declaration"
              state = 0
            end
          elsif val then
            unless state == 3 then
              parse_error "unexpected `#{val[0,1]}' found in XML declaration"
            else
              val.chop!
              val[0,1] = ''
              yield attname, val
            end
            state = 0
          elsif delim then
            if delim == '=' and state == 2 then
              state = 3
            else
              parse_error "unexpected `#{delim}' found in XML declaration"
              state = 0
            end
          elsif e then
            if @src.delete_tag_end then
              state = nil
            else
              parse_error "unexpected `#{e}' found in XML declaration"
              state = 0
            end
          else
            state = 1 if state == 0
          end
        }
      end while state and s = @src.pop_text
      parse_error "unterminated XML declaration meets EOF" unless s
    end


    def scan_xmldecl(s)
      version = nil
      encoding = nil
      standalone = nil
      order = 0
      each_decl_xmldecl(s) { |key,val|
        if key == 'version' then
          unless order == 0 then
            parse_error "`version' must be first in XML declaration"
          end
          version = val
          unless /\A[-a-zA-Z0-9_.:]+\z/ =~ version then
            parse_error "invalid version string `#{version}'"
          end
        elsif key == 'encoding' then
          unless order <= 1 then
            parse_error "`encoding' must be second in XML declaration"
          end
          encoding = val
          unless /\A[A-Za-z][-A-Za-z0-9._]*\z/ =~ encoding then
            parse_error "invalid encoding `#{encoding}'"
          end
          order = 1 if order < 1
        elsif key == 'standalone' then
          unless order <= 2 then
            parse_error "`standalone' must be third in XML declaration"
          end
          if val == 'yes' then
            standalone = true
          elsif val == 'no' then
            standalone = false
          else
            parse_error "`standalone' must be either `yes' or `no'"
          end
          order = 2 if order < 2
        else
          parse_error "invalid declaration `#{key}' in XML declaration"
        end
        order += 1
      }
      on_xmldecl version, encoding, standalone
    end



    def scan_internal_dtd(s)
      parse_error "internal DTD subset is not supported"
      nest = 0
      quote = nil
      begin
        finished = false
        s.scan(/(["']|\A<!--|\A<\?|--\z|\?\z)|\A([<>])|\]\s*\z/) { |q,tag|
          if q then
            if q == '--' or q == '?' then
              quote = nil if q == quote and @src.tag_end?
            elsif q == quote then
              quote = nil
            elsif not quote then
              quote = q.sub(/\A<\!?/, '')
            end
          elsif tag and not quote then
            if tag == '<' then
              nest += 1
            elsif nest > 0 then
              nest -= 1
            end
          elsif nest == 0 then
            finished = true
          end
        }
      end while not (finished and @src.tag_end?) and s = @src.pop_text
    end


    def doctype_ended?(args)
      args == 1 or args == 4
    end


    def scan_doctype(s)
      root = pubid = sysid = nil
      state = 0
      begin
        s2 = nil
        s.scan(/\s+|([^\s\/'"=\[]+)|('[^']*'?|"[^"]*"?)|(.)/
               ) { |sym,str,delim|
          if sym then
            if state == 0 then
              root = sym
              state = 1
            elsif state == 1 and sym == 'PUBLIC' then
              state = 2
            elsif state == 1 and sym == 'SYSTEM' then
              state = 3
            else
              parse_error "unexpected token `#{sym}' in DOCTYPE"
            end
          elsif str then
            if state == 2 then
              pubid = str
              state = 3
            elsif state == 3 then
              sysid = str
              state = 4
            else
              parse_error "unexpected token `#{str[0,1]}' in DOCTYPE"
            end
            qmark = str.slice!(0)
            if str[-1] == qmark then
              str.chop!
            else
              re = /#{qmark.chr}/
              begin
                s2 = @src.pop_text
                unless s2 then
                  parse_error "unterminated string meets EOF"
                  break
                end
                v, s2 = s2.split(re, 2)
                str << v
              end until s2
            end
          elsif delim then
             if delim == '[' and (state == 1 or state == 4) then
              on_doctype root, pubid, sysid
              scan_internal_dtd $'
              state = nil
              break
            else
              parse_error "unexpected token `#{delim}' in DOCTYPE"
            end
          end
        }
      end while s = s2 || @src.pop_until_tagdelim
      if state then
        unless doctype_ended?(state) then
          parse_error "too few arguments in DOCTYPE"
        end
        on_doctype root, pubid, sysid
      end
    end



    def scan_prolog
      s = @src.pop_text   # not @src.pop, in order to preserve first `>'
      if /\A<\?xml\s+/ =~ s then
        scan_xmldecl $'
        s = @src.pop
      end
      while s
        if s[0] == ?< then
          if (c = s[1]) == ?! then
            if s[2] == ?- and s[3] == ?- then
              scan_comment s
            elsif /\A<!DOCTYPE\s+/ =~ s then
              scan_doctype $'
            else
              break
            end
          elsif c == ?? then
            scan_pi s
          else
            break
          end
        elsif s.strip.empty? then
          on_chardata s
        else
          break
        end
        s = @src.pop
      end
      @prolog = false
      s and scan_body(s)
    end



    public

    def step
      if @prolog then
        scan_prolog
        self
      elsif s = @src.pop then
        scan_body s
        if @src.eof? then
          on_eof
          nil
        else
          self
        end
      else
        nil
      end
    end


    def parse(src = nil)
      feed src if src
      scan_prolog if @prolog
      while s = @src.pop
        scan_body s
      end
      on_eof
      self
    end

  end


end





if $0 == __FILE__ then
  class TestScanner < XMLScan::XMLScanner
    def parse_error(msg)
      STDERR.printf("%s:%d: %s\n", path, lineno, msg) if $VERBOSE
    end
    def wellformed_error(msg)
      STDERR.printf("%s:%d: WFC: %s\n", path, lineno, msg) if $VERBOSE
    end
  end
  src = ARGF.read
  scan = TestScanner.new
  t1 = Time.times.utime
  scan.parse src
  t2 = Time.times.utime
  STDERR.printf "%2.3f sec\n", t2 - t1
end
