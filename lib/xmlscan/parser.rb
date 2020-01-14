#
# parser.rb
#
#   Copyright (C) Ueno Katsuhiro 2000,2001
#
# $Id: parser.rb,v 1.1.2.10 2001/11/23 14:51:34 katsu Exp $
#

=begin
= xmlscan/parser.rb

100% pure Ruby XML parser.
It handles XML documents by "Visitor" pattern.


== XMLScan::ValidityConstraintViolation

The exception raised when XML document is not valid.

`xmlscan' doesn't provide validating XML parser now.
This exception is reserved for future use.

=== SuperClass:

* ((<XMLScan::Error>))

== XMLScan::VCViolation

The alias of ((<XMLScan::ValidityConstraintViolation>)).


== XMLScan::NamespacesConstraintViolation

The exception raised when XML document violates namespaces constraint.

=== SuperClass:

* ((<XMLScan::Error>))

== XMLScan::NSCViolation

The alias of ((<XMLScan::NamespacesConstraintViolation>)).


== XMLScan::XMLVisitor

The mix-in module for XML element tree visitor classes for
((<XMLScan::XMLParser>)).

=== Methods:

--- XMLScan::XMLVisitor#parse_error(path, lineno, msg)
        Called when a parse error is found.
--- XMLScan::XMLVisitor#wellformed_error(path, lineno, msg)
        Called when a well-formedness constraint violation is found.
--- XMLScan::XMLVisitor#on_xmldecl(version, encoding, standalone)
        Called when the parser meets a XML declaration.
--- XMLScan::XMLVisitor#on_doctype(root, pubid, sysid)
        Called when the parser meets a DOCTYPE declaration.
--- XMLScan::XMLVisitor#on_comment(str)
        Called when the parser meets a comment.
--- XMLScan::XMLVisitor#on_pi(target, pi)
        Called when the parser meets a processing instructions.
--- XMLScan::XMLVisitor#on_chardata(str)
        Called when the parser meets character data.
--- XMLScan::XMLVisitor#on_cdata(str)
        Called when the parser meets a CDATA section.
--- XMLScan::XMLVisitor#on_start_element(name, attr)
        Called when the parser meets a start tag.
--- XMLScan::XMLVisitor#on_end_element(name)
        Called when the parser meets a end tag.

--- XMLScan::XMLVisitor#on_entityref(ref)
        Called when the parser meets a general entity reference.

        ((*FIXME: You must return SOMETHING*)):
        The entity reference resolving architecture of xmlscan
        is not fixed yet. Return non-nil value for the time being.

--- XMLScan::XMLVisitor#on_entityref_in_attr(ref)
        Called when a general entity reference
        is found in an attribute value.

        ((*FIXME: You must return SOMETHING*)):
        The entity reference resolving architecture of xmlscan
        is not fixed yet. Return a replacement text of general parsed
        entity ((|ref|)) for the time being.

--- XMLScan::XMLVisitor#character_reference(code)
        Called when the parser meets a character reference.

        You must return a string which contains a character specified
        by ((|code|)).


== XMLScan::XMLParser

The class for parsing XML document.

=== LIMITATIONS

  * The limitations of ((<XMLScan::XMLScanner>)) are all applied to
    XMLScan::XMLParser.
  * All syntax defined in XML Specification are completely implemented
    except external and internal DTD subset.
  * Not a validating parser.
  * It checks for well-formedness, but not all well-formedness checks
    are implemented. These checks are being added. See CONFORMANCE
    for what is supported and what is not.

=== SuperClass:

* ((<XMLScan::XMLScanner>))

=== Class Methods:

--- XMLScan::XMLParser.new(visitor[, port])
        Creates a new parser object. ((|visitor|)) is an instance of
        visitor class for traversing XML element tree. The visitor class
        must include ((<XMLScan::XMLVisitor>)) or
        ((<XMLScan::XMLNamespaceVisitor>)) module.

        The meaning of ((|port|)) is same as
        ((<feed|XMLScan::XMLParser#feed>)).

=== Methods:

--- XMLScan::XMLParser#feed(port)
        Sets ((|port|)) as a source object. See the description of
        ((<XMLScan::XMLScanner#feed>)) method for detail.

--- XMLScan::XMLParser#parse([port])
        Parses the source. Each specific method of the visitor object
        is called when the parser object meets each syntactic element.


== XMLScan::XMLNamespaceVisitor

The mix-in module for XML element tree visitor classes for
((<XMLScan::XMLNamespaceParser>)).

This module can also be used for ((<XMLScan::XMLParser>))
instead of ((<XMLScan::XMLVisitor>)) module.

=== Including Module:

* ((<XMLScan::XMLVisitor>))

=== Methods:

--- XMLScan::XMLNamespaceVisitor#ns_error(path, lineno, msg)
        Called when a namespaces constraint violation is found.
        By default, this method raises
        ((<XMLScan::NamespacesConstraintViolation>)).

--- XMLScan::XMLNamespaceVisitor#on_start_element_ns(uri, prefix, localpart, attr)
        Called when the parser meets a start tag.

        ((<XMLScan::XMLNamespaceVisitor>)) object never calls
        ((<on_start_element|XMLScan::XMLVisitor#on_start_element>))
        method and calls this method instead.

--- XMLScan::XMLNamespaceVisitor#on_end_element_ns(uri, prefix, localpart)
        Called when the parser meets a end tag.

        ((<XMLScan::XMLNamespaceVisitor>)) object never calls
        ((<on_end_element|XMLScan::XMLVisitor#on_end_element>))
        method and calls this method instead.


== XMLScan::XMLNamespaceParser

The class for parsing XML documents with XML Namespaces.

=== LIMITATIONS

  * See ((<XMLScan::XMLParser>)).

=== SuperClass:

* ((<XMLScan::XMLParser>))

=== Class Methods:

--- XMLScan::XMLNamespaceParser.new(visitor[, port])
        Creates a new parser object. ((|visitor|)) is an instance of
        visitor class to traverse XML element tree. The visitor class must
        include ((<XMLScan::XMLNamespaceVisitor>)) module.

        The meaning of ((|port|)) is same as
        ((<feed|XMLScan::XMLParser#feed>)).

=end



require 'xmlscan/scanner'


module XMLScan

  class ValidityConstraintViolation < Error ; end
  VCViolation = ValidityConstraintViolation

  class NamespacesConstraintViolation < Error ; end
  NSCViolation = NamespacesConstraintViolation



  module XMLVisitor

    def parse_error(path, lineno, msg)
      raise ParseError, sprintf('%s:%d: %s', path, lineno, msg)
    end

    def wellformed_error(path, lineno, msg)
      raise WFCViolation, sprintf('%s:%d: %s', path, lineno, msg)
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

    def on_start_element(name, attr)
    end

    def on_end_element(name)
    end

    def on_entityref(ref)
      # FIXME: return (parsed?) replacement text, or nil.
      # FIXME: You may not mentioned about predefined entities here.
      # FIXME: Entity reference resolving architecture is not fixed yet :-(
      nil
    end

    def on_entityref_in_attr(ref)
      # FIXME: return plain replacement text, or nil.
      # FIXME: "WFC: No < in Attribute Values" must be considered here.
      # FIXME: You may not mentioned about predefined entities here.
      # FIXME: Entity reference resolving archirecture is not fixed yet :-(
      nil
    end

    def character_reference(code)
      # FIXME: return string which explains the code.
      [code].pack('U')
    end

  end




  class XMLParser < XMLScanner

    class ElementStack < PrivateArray

      def no_element?
        first.nil?       # empty? or first.nil?
      end

      def root_found?
        not empty?
      end

      def push_element(name)
        if first or empty? then
          push name
        else
          pop
          push name
          nil
        end
      end

      def pop_element(name)
        if name == last then
          pop
          push nil if empty?
          self
        else
          nil
        end
      end

      alias current last
      public :current

      def each
        reverse_each { |i| yield i if i }
      end

    end



    def initialize(visitor, *args)
      @visitor = visitor
      super(*args)
    end


    def feed(port)
      @elemstack = ElementStack.new
      super
    end


    private

    def parse_error(msg)
      @visitor.parse_error(path, lineno, msg)
    end

    def wellformed_error(msg)
      @visitor.wellformed_error(path, lineno, msg)
    end

    def on_xmldecl(version, encoding, standalone)
      @visitor.on_xmldecl(version, encoding, standalone)
    end

    def on_doctype(root, pubid, sysid)
      @visitor.on_doctype(root, pubid, sysid)
    end

    def on_comment(str)
      @visitor.on_comment str
    end

    def on_pi(target, pi)
      @visitor.on_pi target, pi
    end

    def on_chardata(str)
      @visitor.on_chardata str
    end

    def on_cdata(str)
      @visitor.on_cdata str
    end


    PredefinedEntity = {
      'lt' => '<', 'gt' => '>', 'amp' => '&', 'quot' => '"', 'apos' => "'",
    }

    def on_entityref(ref)
      rep = @visitor.on_entityref(ref)
      unless rep then
        rep = PredefinedEntity[ref]
        unless rep then
          wellformed_error "undeclared general entity `#{ref}'"
          # FIXME: error recovery code will be here.
          return
        end
      end
      # FIXME: code for handling replacement text will be here.
    end

    def on_entityref_in_attr(ref)
      @visitor.on_entityref_in_attr(ref) or PredefinedEntity[ref] or
        begin
          wellformed_error "undeclared general entity `#{ref}'"
          ''
        end
    end

    def on_charref(code)
      @visitor.on_chardata @visitor.character_reference(code)
    end

    def on_charref_in_attr(code)
      @visitor.character_reference code
    end


    def on_start_element(name, attr)
      @visitor.on_start_element name, attr
    end

    def on_end_element(name)
      @visitor.on_end_element name
    end


    def on_stag(name, attr)
      unless @elemstack.push_element name then
        wellformed_error "another root element `#{name}'"
      end
      on_start_element name, attr
    end

    def on_etag(name)
      unless @elemstack.pop_element name then
        wellformed_error "element type `#{name}' is not matched"
      else
        on_end_element name
      end
    end

    def on_emptyelem(name, attr)
      unless @elemstack.push_element name then
        wellformed_error "another root element `#{name}'"
      end
      on_start_element name, attr
      on_end_element name
      @elemstack.pop_element name
    end


    def on_eof
      if not @elemstack.root_found? then
        wellformed_error "no root element was found"
      elsif not @elemstack.no_element? then
        @elemstack.dup.each { |name|
          wellformed_error "unclosed element `#{name}' meets EOF"
          on_end_element name
          @elemstack.pop_element name
        }
      end
    end

  end




  module XMLNamespaceVisitor

    include XMLVisitor

    def ns_error(path, lineno, msg)
      raise NSCViolation, sprintf('%s:%d: %s', path, lineno, msg)
    end

    def on_start_element_ns(uri, prefix, localpart, attr)
    end

    def on_end_element_ns(uri, prefix, localpart)
    end

  end




  class XMLNamespaceParser < XMLParser

    PredefinedNamespace = {
      'xml' => 'http://www.w3.org/XML/1998/namespace',
      'xmlns' => 'http://www.w3.org/2000/xmlns/',
    }

    class NamespaceStack < PrivateArray

      def initialize
        super
        @namespace = {}
      end

      def namespace
        ret = @namespace.dup
        ret.delete :default
        ret
      end

      def default_namespace
        @namespace[:default]
      end

      def get_namespace(name)
        @namespace[name] or PredefinedNamespace[name]
      end

      def set_namespace(name, uri)
        push [ name, @namespace[uri] ]
        if uri.empty? then
          @namespace.delete name
        else
          @namespace[name] = uri
        end
      end

      def start_element
        push nil
      end

      def end_element
        while log = pop
          if log[1] then
            @namespace[log[0]] = log[1]
          else
            @namespace.delete log[0]
          end
        end
      end

    end



    def feed(port)
      @nsstack = NamespaceStack.new
      super
    end

    def ns_prefixes
      @nsstack.namespace
    end


    private

    def ns_error(msg)
      @visitor.ns_error(path, lineno, msg)
    end


    def expand_qname(name, default = nil)
      unless /:/ =~ name then
        [ default && @nsstack.default_namespace, nil, name ]
      else
        prefix, localpart = $`, $'
        if localpart.empty? then
          ns_error "`:' is found in QName `#{name}' without any localpart"
          return [ nil, nil, name ]
        elsif /:/ =~ localpart then
          ns_error "localpart `#{localpart}' must not contain colon"
        end
        unless namespace = @nsstack.get_namespace(prefix) then
          ns_error "undeclared namespace `#{prefix}'"
          namespace = nil
        end
        [ namespace, prefix, localpart ]
      end
    end


    def expand_attribute(attr)
      attr.collect { |key,value|
        ns, prefix, localpart = expand_qname(key)
        if key == 'xmlns' then
          @nsstack.set_namespace :default, value
        elsif prefix == 'xmlns' then
          if localpart[0,3].downcase == 'xml' then
            ns_error "namespace name `#{localpart}' is reserved"
          elsif value.empty? then
            ns_error "namespace URI for `#{localpart}' is empty"
          elsif /\s/ =~ value then
            ns_error "invalid namespace URI `#{value}'"
          else
            @nsstack.set_namespace localpart, value
          end
        end
        [ ns, prefix, localpart, value ]
      }
    end


    def on_start_element(name, attr)
      @nsstack.start_element
      attr = expand_attribute(attr)
      uri, prefix, localpart = expand_qname(name, true)
      @visitor.on_start_element_ns uri, prefix, localpart, attr
    end

    def on_end_element(name)
      @visitor.on_end_element_ns(*expand_qname(name, true))
      @nsstack.end_element
    end

    def on_pi(target, pi)
      ns_error "PI target must not contain colon" if /:/ =~ target
      super
    end

  end


end





if $0 == __FILE__ then

  module Loose
    def parse_error(path, lineno, msg)
      STDERR.printf("%s:%d: %s\n", path, lineno, msg) if $VERBOSE
    end
    def wellformed_error(path, lineno, msg)
      STDERR.printf("%s:%d: WFC: %s\n", path, lineno, msg) if $VERBOSE
    end
    def ns_error(path, lineno, msg)
      STDERR.printf("%s:%d: NS: %s\n", path, lineno, msg) if $VERBOSE
    end
  end
  class LooseVisitor
    include XMLScan::XMLVisitor
    include Loose
  end
  class LooseNSVisitor
    include XMLScan::XMLNamespaceVisitor
    include Loose
  end

  src = XMLScan.normalize_linebreaks(ARGF.read)
  p = XMLScan::XMLParser.new(LooseVisitor.new)
  t1 = Time.times.utime
  p.parse src
  t2 = Time.times.utime
  STDERR.printf "XMLParser: %2.3f sec\n", t2 - t1

  p = XMLScan::XMLNamespaceParser.new(LooseNSVisitor.new)
  t1 = Time.times.utime
  p.parse src
  t2 = Time.times.utime
  STDERR.printf "XMLNamespaceParser: %2.3f sec\n", t2 - t1

end
