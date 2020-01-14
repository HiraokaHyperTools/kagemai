#
# iterate.rb
#
#   Copyright (C) Ueno Katsuhiro 2001
#
# $Id: iterate.rb,v 1.1.2.5 2001/06/02 08:43:02 katsu Exp $
#

=begin
= xmlscan/iterate.rb

Iterator version of XML parser.

== XMLScan::IterateXMLParser

100% pure Ruby XML parser.
It handles XML document by iterator.

=== LIMITATIONS

  * See ((<XMLScan::XMLParser>)).

=== SuperClass:

* ((<Object>))

=== Included Module:

* ((<XMLScan::XMLVisitor>))

=== Class Methods:

--- XMLScan::IterateXMLParser.new
        Creates a new parser object.

=== Methods:

--- XMLScan::IterateXMLParser#parse(port)
        Parses ((|port|)) and calls the given block when the parser
        object meets each syntactic elements.

        The block takes 3 arguments: First argument is the type of
        the syntactic element. Second one is the name of it. And third
        one is extra data for it.
=end
=begin RT
        type                 , name      , data
        :error               , class     , msg
        :xmldecl             , (({nil})) , [version, encoding, standalone]
        :doctype             , (({nil})) , [root, pubid, sysid]
        :coment              , (({nil})) , str
        :pi                  , target    , pi
        :cdata               , (({nil})) , str
        :start_elem          , name      , attr
        :end_elem            , name      , (({nil}))
        :entityref           , ref       , (({nil}))
        :entityref_in_attr   , ref       , (({nil}))
        :character_reference , code      , (({nil}))
=end RT
=begin

--- XMLScan::IterateXMLParser#path
        Returns filename which is being parsed.
        Unexpected value should be returned depending on the type of
        the source object.

--- XMLScan::IterateXMLParser#lineno
        Returns line number where is being parsed.
        Unexpected value should be returned depending on the type of
        the source object.


== XMLScan::IterateXMLNamespaceParser

((<XMLScan::IterateXMLParser>)) with XML Namespaces support.

=== LIMITATIONS:

  * See ((<XMLScan::XMLParser>)).

=== SuperClass:

* ((<XMLScan::IterateXMLParser>))

=== Included Module:

* ((<XMLScan::XMLNamespaceVisitor>))

=end



require 'xmlscan/parser'


module XMLScan

  class IterateXMLParser

    include XMLVisitor

    def initialize
      @parser = XMLParser.new(self)
    end

    def parse(port, &block)
      begin
        @block = block
        @parser.parse(port)
      ensure
        @block = nil
      end
    end

    def path
      @parser.path
    end

    def lineno
      @parser.lineno
    end

    def parse_error(path, lineno, msg)
      @block.call :error, ParseError, msg
    end

    def wellformed_error(path, lineno, msg)
      @block.call :error, WFCViolation, msg
    end

    def on_xmldecl(version, encoding, standalone)
      @block.call :xmldecl, nil, [version, encoding, standalone]
    end

    def on_doctype(root, pubid, sysid)
      @block.call :doctype, nil, [root, pubid, sysid]
    end

    def on_comment(str)
      @block.call :comment, nil, str
    end

    def on_pi(target, pi)
      @block.call :pi, target, pi
    end

    def on_chardata(str)
      @block.call :cdata, nil, str
    end

    def on_cdata(str)
      @block.call :cdata, nil, str
    end

    def on_start_element(name, attr)
      @block.call :start_elem, name, attr
    end

    def on_end_element(name)
      @block.call :end_elem, name, nil
    end

    def on_entityref(ref)
      @block.call :entityref, ref, nil
      nil
    end

    def on_entityref_in_attr(ref)
      @block.call :entityref_in_attr, ref, nil
      ''
    end

    def character_reference(code)
      @block.call :character_reference, code, nil
      ''
    end

  end



  class IterateXMLNamespaceParser < IterateXMLParser

    include XMLNamespaceVisitor

    def initialize
      @parser = XMLNamespaceParser.new(self)
    end

    def ns_error(path, lineno, msg)
      @block.call :error, NSViolation, msg
    end

    def on_start_element_ns(uri, prefix, localpart, attr)
      @block.call :start_elem, [ uri, prefix, localpart ], attr
    end

    def on_end_element_ns(uri, prefix, localpart)
      @block.call :end_elem, [ uri, prefix, localpart ], nil
    end

  end

end



if $0 == __FILE__ then
  src = XMLScan.normalize_linebreaks(ARGF.read)
  #XMLScan::IterateXMLParser.new.parse(src) { |type,name,data|
  XMLScan::IterateXMLNamespaceParser.new.parse(src) { |type,name,data|
    p [ type, name, data ]
  }
end
