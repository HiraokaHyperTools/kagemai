#
# xpathtree.rb
#
#   Copyright (C) Ueno Katsuhiro 2000,2001
#
# $Id: xpathtree.rb,v 1.1.2.2 2001/11/23 13:38:11 katsu Exp $
#

require 'xmlscan/parser'
require 'xmlscan/xpath'


module XMLScan

  module XPath

    # obediently implementation of XPath data model

    module DataModel

      class Node < NullNodeAdapter

        def initialize
          @parent = nil
          # @index = 0
        end

        attr_accessor :parent
        protected :parent=

        # attr_accessor :index
        # protected :index=

        def append_child
          raise "can't take any children"
        end

        def node
          self
        end

        def root
          (p = @parent) and p.root
        end

        def lang
          (p = @parent) and p.lang
        end

        def each_following_siblings
          if @parent then
            nodes = @parent.children
            n = nodes.index(self)
            raise "BUG" unless n
            (n + 1).upto(nodes.size - 1) { |i| yield nodes[i] }
          end
        end

        def each_preceding_siblings
          if @parent then
            nodes = @parent.children
            n = nodes.index(self)
            raise "BUG" unless n
            (n - 1).downto(0) { |i| yield nodes[i] }
          end
        end

        def index
          unless @parent then
            0
          else
            n = @parent.children.index(self)
            raise "BUG" unless n
            n
          end
        end


        def namespace_decls
          nil
        end

        def traverse(level = 0, &block)
          block.call level, self
          children.each { |node| node.traverse(level + 1, &block) }
        end

        def abs_index
          indices = []
          node = self
          while node
            indices.push node.index
            node = node.parent
          end
          indices.reverse!
          indices.join(':')
        end

        def inspect
          uri = namespace_uri
          qname = qualified_name
          strval = string_value
          dst = "<#{node_type.id2name.capitalize} #{abs_index}"
          dst << " qname=#{qname.dump}" if qname
          dst << " ns=#{uri.dump}" if uri
          dst << " str=#{strval.inspect}" if strval
          dst << ">"
        end

      end



      class ParentNode < Node

        def initialize
          @children = []
          super
        end

        attr_reader :children

        def append_child(node)
          # node.index = @children.size
          @children.push node
          node.parent = self
        end

        def string_value
          @children.collect{ |i| i.string_value }.join
        end

      end



      class RootNode < ParentNode

        private :parent=

        def root
          self
        end

        def node_type
          :root
        end

      end



      module NamedNode

        def initialize(namespace_uri, prefix, localpart)
          @namespace_uri = namespace_uri
          @name_prefix, @name_localpart = prefix, localpart
          super()
        end

        attr_reader :namespace_uri, :name_localpart

        def qualified_name
          if @name_prefix then
            @name_prefix + ':' + @name_localpart
          else
            @name_localpart
          end
        end

      end



      class ElementNode < ParentNode

        include NamedNode

        def initialize(namespace_uri, prefix, localpart, attrs, namespaces)
          @namespaces = namespaces
          @attrnodes = make_attr_nodes(attrs)
          @namespacenodes = make_namespace_nodes(namespaces)
          super namespace_uri, prefix, localpart
        end

        private

        def make_namespace_nodes(namespaces)
          dst = []
          namespaces.each { |k,v|
            node = NamespaceNode.new(k, v)
            node.parent = self
            dst.push node
          }
          dst
        end

        def make_attr_nodes(attrs)
          attrs.collect { |uri,prefix,name,val|
            node = AttributeNode.new(uri, prefix, name, val)
            node.parent = self
            node
          }
        end

        public

        def node_type
          :element
        end

        def lang
          lang = nil
          @attrnodes.each { |node|
            if node.name_localpart == 'lang' and
                node.namespace_uri == 'http://www.w3.org/XML/1998/namespace' then
              lang = node.string_value
              break
            end
          }
          lang or super
        end

        def attributes
          @attrnodes
        end

        def namespaces
          @namespacenodes
        end


        def namespace_decls
          @namespaces
        end

        def traverse(level = 0, &block)
          block.call level, self
          namespaces.each { |node| node.traverse(level + 1, &block) }
          attributes.each { |node| node.traverse(level + 1, &block) }
          children.each { |node| node.traverse(level + 1, &block) }
        end

      end



      class NamespaceNode < Node

        def initialize(prefix, uri)
          @name_localpart, @string_value = prefix, uri
          super()
        end

        attr_reader :name_localpart, :string_value

        def node_type
          :namespace
        end

        def index
          a = @parent.namespaces
          a.index(self) - a.size - @parent.attributes.size
        end

      end



      class AttributeNode < Node

        include NamedNode

        def initialize(namespace_uri, prefix, localpart, value)
          @string_value = value
          super namespace_uri, prefix, localpart
        end

        attr_reader :string_value

        def node_type
          :attribute
        end

        def index
          a = @parent.attributes
          a.index(self) - a.size
        end

        def namespace_decls
          @parent.namespace_decls
        end

      end



      class TextNode < Node

        def initialize(text)
          @string_value = text
          super()
        end

        attr_reader :string_value

        def node_type
          :text
        end

      end



      class CommentNode < TextNode

        def node_type
          :comment
        end

      end



      class PINode < TextNode

        def initialize(target, pi)
          @name_localpart = target
          super pi
        end

        attr_reader :name_localpart

        def node_type
          :processing_instruction
        end

      end



      class Builder

        include XMLScan::XMLNamespaceVisitor

        def parse_error(*args)
        end

        def wellformed_error(*args)
        end

        def initialize
          @parser = XMLScan::XMLNamespaceParser.new(self)
        end

        def parse(*args)
          @root = RootNode.new
          @nodestack = [ @root ]
          @parser.parse(*args)
          @root
        end

        def on_chardata(str)
          node = TextNode.new(str)
          @nodestack[-1].append_child node
        end

        def on_comment(strs)
          node = CommentNode.new(strs)
          @nodestack[-1].append_child node
        end

        def on_pi(target, pi)
          super
          node = PINode.new(target, pi)
          @nodestack[-1].append_child node
        end

        def expand_attr_namespace(attr)
          dst = []
          attr.each { |key,val|
            namespace, prefix, name = expand_qualified_name(key)
            dst.push [ namespace, prefix, name, val ]
          }
          dst
        end

        def on_start_element_ns(uri, prefix, localpart, attr)
          node = ElementNode.new(uri,prefix,localpart,attr,@parser.ns_prefixes)
          @nodestack[-1].append_child node
          @nodestack.push node
        end

        def on_end_element_ns(uri, prefix, localpart)
          @nodestack.pop
        end

      end


    end

  end

end



if $0 == __FILE__ then

  require 'readline'

  STDOUT.sync = STDERR.sync = true
  unless $DEBUG then
    compiler = XMLScan::XPath::DefaultCompiler
  else
    compiler = XMLScan::XPath::Compiler.new(true)
  end

  raise "requires 1 argument" unless ARGV[0]
  STDERR.print "parsing #{ARGV[0]} ... "
  current_node = XMLScan::XPath::DataModel::Builder.new.parse(File.open(ARGV[0]))
  STDERR.print "done.\n"
  variables = {}
  namespaces = {}

  if $DEBUG then
    current_node.traverse { |level,node| print '  ' * level, node.inspect, "\n" }
  end

  while src = Readline.readline("xpath:#{current_node.abs_index}> ", true)
    case src
    when /\Acd\s+/ then
      src = $'
      op = :cd
    when /\A\$(\w+)\s*=\s*/ then
      src = $'
      op = [ :var, $1 ]
    when /\Axmlns:(\w+)\s*=/ then
      namespaces[$1] = $'.strip
      next
    when ';variables' then
      variables.each { |k,v| print "$#{k} = #{v.to_ruby.inspect}\n" }
      next
    when ';namespaces' then
      namespaces.each { |k,v| print "xmlns:#{k} = #{v}\n" }
      next
    else
      op = nil
    end

    begin
      context = XMLScan::XPath::Context.new(current_node, namespaces, variables)
      t1 = Time.times.utime
      proc = compiler.compile(src)
      t2 = Time.times.utime
      result = proc.call(context, false)
      t3 = Time.times.utime
      op, arg = op
      variables[arg] = result if op == :var
      if result.is_a? XMLScan::XPath::XPathNodeSet then
        result = result.to_ruby
        result.each { |i| print i.inspect, "\n" }
        current_node = result[0] if op == :cd
      else
        p result.to_ruby
      end
      printf "compile: %.2f sec  eval: %.2f sec\n", t2 - t1, t3 - t2
    rescue XMLScan::XPath::Error
      at = $@
      printf "%s: %s (%s)\n", at.shift, $!, $!.type
      at.each { |i| print "\tfrom ", i, "\n" }
    end
  end

end
