#
# htmlscan.rb
#
#   Copyright (C) Ueno Katsuhiro 2000,2001
#
# $Id: htmlscan.rb,v 1.1.2.3 2001/05/23 22:34:38 katsu Exp $
#

=begin
= xmlscan/htmlscan.rb

100% pure Ruby HTML parser.


== XMLScan::UseXMLScanner

The exception raised when a XML declaration is found in HTML document.

=== SuperClass:

* ((<XMLScan::Error>))


== XMLScan::HTMLScanner

HTML parser based on XMLScan::XMLScanner.

=== SuperClass:

* ((<XMLScan::XMLScanner>))

=end



require 'xmlscan/scanner'


module XMLScan

  class UseXMLScanner < Error ; end


  class HTMLScanner < XMLScanner

    private

    def on_emptyelem(name, attr)
      parse_error "parse error at `/'"
      on_stag name, attr
    end

    def on_pi(target, pi)
      parse_error "processing instructions is not allowed in HTML"
    end

    def on_cdata(s)
      parse_error "CDATA section is not allowed in HTML"
      on_chardata s
    end


    def scan_unquoted_attvalue(v)
      scan_attvalue v
    end

    def scan_omitted_attvalue(v)
      v
    end


    def scan_bang_tag(s)
      parse_error "parse error at `<!'"
      @src.skip_until_tagdelim
    end


    def scan_xmldecl(s)
      raise UseXMLScanner, "XML declaration is found. use XMLScanner instead"
    end

    def scan_internal_dtd(s)
      parse_error "internal DTD subset is not allowed in HTML"
      @src.skip_until_tagdelim
    end

    def doctype_ended?(args)
      args == 1 or args == 3 or args == 4
    end

  end

end






if $0 == __FILE__ then
  class TestScanner < XMLScan::HTMLScanner
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
