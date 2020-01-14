#
# xpath-dom.rb
#
#   Copyright (C) Ueno Katsuhiro 2000
#
# $Id: xpath-dom.rb,v 1.1.2.1 2001/05/02 13:29:18 katsu Exp $
#

require 'xmltreebuilder'
require 'xpath'


module XPath

  module DOM

    class AbstractNodeAdapter < NullNodeAdapter

      def wrap(node, visitor)
        @node = node
        self
      end

      attr_reader :node

      def root
        @node.ownerDocument
      end

      def parent
        @node.parentNode
      end

      def children
        @node.childNodes.to_a
      end

      def each_following_siblings
        node = @node
        yield node while node = node.nextSibling
      end

      def each_preceding_siblings
        node = @node
        yield node while node = node.previousSibling
      end

      def index
        @node.parentNode.childNodes.to_a.index(@node)
      end

      def lang
        node = @node
        lang = nil
        until a = node.attributes and lang = a.getNamedItem('xml:lang')
          node = node.parentNode
        end
        lang and lang.nodeValue
      end

    end


    class TextNodeAdapter < AbstractNodeAdapter

      def node_type
        :text
      end

      def string_value
        @node.nodeValue
      end

    end


    class CommentNodeAdapter < TextNodeAdapter

      def node_type
        :comment
      end

    end


    class PINodeAdapter < AbstractNodeAdapter

      def node_type
        :processing_instruction
      end

      def name_localpart
        @node.nodeName
      end

      def string_value
        @node.nodeValue
      end

    end


    class ParentNodeAdapter < AbstractNodeAdapter

      def string_value
        dst = ''
        stack = @node.childNodes.to_a.reverse
        while node = stack.pop
          s = node.nodeValue
          dst << s if s
          stack.concat node.childNodes.to_a.reverse
        end
        dst
      end

    end


    class RootNodeAdapter < ParentNodeAdapter

      def node_type
        :root
      end

      alias root node

      def index
        0
      end

    end


    class ElementNodeAdapter < ParentNodeAdapter

      def wrap(node, visitor)
        @node = node
        @visitor = visitor
        self
      end

      def node_type
        :element
      end

      def name_localpart
        @node.nodeName
      end

      def attributes
        map = @node.attributes
        attrs = @visitor.get_attributes(@node)
        unless attrs then
          attrs = []
          map.length.times { |i| attrs.push map.item(i) }
          @visitor.regist_attributes @node, attrs
        end
        attrs
      end

    end


    class AttrNodeAdapter < AbstractNodeAdapter

      def wrap(node, visitor)
        @node = node
        @visitor = visitor
        self
      end

      def node_type
        :attribute
      end

      def name_localpart
        @node.nodeName
      end

      def parent
        @visitor.get_attr_parent @node
      end

      def index
        -@visitor.get_attributes(parent).index(@node)
      end

      def string_value
        @node.nodeValue
      end

    end



    class NodeVisitor

      def initialize
        @adapters = Array.new(12, NullNodeAdapter.new)
        @adapters[XML::DOM::Node::ELEMENT_NODE] = ElementNodeAdapter.new
        @adapters[XML::DOM::Node::ATTRIBUTE_NODE] = AttrNodeAdapter.new
        @adapters[XML::DOM::Node::TEXT_NODE] =
          @adapters[XML::DOM::Node::CDATA_SECTION_NODE] = TextNodeAdapter.new
        @adapters[XML::DOM::Node::PROCESSING_INSTRUCTION_NODE] =
          PINodeAdapter.new
        @adapters[XML::DOM::Node::COMMENT_NODE] = CommentNodeAdapter.new
        @adapters[XML::DOM::Node::DOCUMENT_NODE] = RootNodeAdapter.new
        @attr = {}
      end

      def visit(node)
        @adapters[node.nodeType].wrap(node, self)
      end

      def regist_attributes(node, attrs)
        @attr[node] = attrs
        attrs.each { |i| @attr[i] = node }
      end

      def get_attributes(node)
        @attr[node]
      end

      def get_attr_parent(node)
        @attr[node]
      end

    end



    class Context < XPath::Context

      def initialize(node, namespace = nil, variable = nil)
        super node, namespace, variable, NodeVisitor.new
      end

    end


  end

end




module XML

  module DOM

    class Node

      def getNodesByXPath(xpath)
        xpath = XPath.compile(xpath) unless xpath.is_a? XPath::XPath
        ret = xpath.call(XPath::DOM::Context.new(self))
        raise "return value is not NodeSet" unless ret.is_a? Array
        ret
      end

      def _getMyLocationInXPath(parent)
        n = parent.childNodes.index(self)
        "node()[#{n + 1}]"
      end

      def makeXPath
        dst = []
        node = self
        while parent = node.parentNode
          dst.push node._getMyLocationInXPath(parent)
          node = parent
        end
        dst.reverse!
        '/' + dst.join('/')
      end

    end


    class Element

      def _getMyLocationInXPath(parent)
        name = nodeName
        n = parent.childNodes.to_a.select { |i|
          i.nodeType == ELEMENT_NODE and i.nodeName == name
        }.index(self)
        "#{name}[#{n + 1}]"
      end

    end


    class Text

      def _getMyLocationInXPath(parent)
        n = parent.childNodes.to_a.select { |i|
          i.nodeType == TEXT_NODE or i.nodeType == CDATA_SECTION_NODE
        }.index(self)
        "text()[#{n + 1}]"
      end

    end


    class CDATASection

      def _getMyLocationInXPath(parent)
        n = parent.childNodes.to_a.select { |i|
          i.nodeType == TEXT_NODE or i.nodeType == CDATA_SECTION_NODE
        }.index(self)
        "text()[#{n + 1}]"
      end

    end


    class Comment

      def _getMyLocationInXPath(parent)
        n = parent.childNodes.to_a.select { |i|
          i.nodeType == COMMENT_NODE
        }.index(self)
        "comment()[#{n + 1}]"
      end

    end


    class ProcessingInstruction

      def _getMyLocationInXPath(parent)
        n = parent.childNodes.to_a.select { |i|
          i.nodeType == PROCESSING_INSTRUCTION_NODE
        }.index(self)
        "processing-instruction()[#{n + 1}]"
      end

    end


    class Attr

      def makeXPath
        '@' + nodeName
      end

    end


  end

end






if $0 == __FILE__ then

  require 'readline'
  require 'uconv'
  $KCODE = 'U'

  STDOUT.sync = STDERR.sync = true
  module XPath
    @compiler = Compiler.new(true) if $DEBUG
  end

  raise "requires 1 argument" unless ARGV[0]
  STDERR.print "parsing #{ARGV[0]} ... "
  doc = XML::DOM::Builder.new.parse(File.open(ARGV[0]).read)
  STDERR.print "done.\n"
  context = XPath::DOM::Context.new(doc)

  while src = Readline.readline("xpath:#{context.node.makeXPath}> ", true)
    src = Uconv.euctou8(src)
    cd = (/\Acd\s+/ =~ src)
    src = $' if cd
    begin
      t1 = Time.times.utime
      proc = XPath.compile(src)
      t2 = Time.times.utime
      result = proc.call(context)
      t3 = Time.times.utime
      if result.is_a? Array and not result.empty? then
        result.each { |i| print i.makeXPath, "\n" }
        context.reuse result[0] if cd
      else
        p result
      end
      printf "compile: %.2f sec  eval: %.2f sec\n", t2 - t1, t3 - t2
    rescue XPath::Error
      at = $@
      printf "%s: %s (%s)\n", at.shift, $!, $!.type
      at.each { |i| print "\tfrom ", i, "\n" }
    end
  end

end
