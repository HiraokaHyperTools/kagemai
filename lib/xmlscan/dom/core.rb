#
# dom/core.rb
#
#   Copyright (C) Ueno Katsuhiro 2000,2001
#
# $Id: core.rb,v 1.1.2.1 2001/05/23 13:29:09 katsu Exp $
#

require 'xmlscan/parser'


module XMLScan

  module DOM

    DOMString = String
    DOMTimeStamp = Integer



    ExceptionTypes = {   # Ruby specific
      'INDEX_SIZE_ERR'              => 1,
      'DOMSTRING_SIZE_ERR'          => 2,
      'HIERARCHY_REQUEST_ERR'       => 3,
      'WRONG_DOCUMENT_ERR'          => 4,
      'INVALID_CHARACTER_ERR'       => 5,
      'NO_DATA_ALLOWED_ERR'         => 6,
      'NO_MODIFICATION_ALLOWED_ERR' => 7,
      'NOT_FOUND_ERR'               => 8,
      'NOT_SUPPORTED_ERR'           => 9,
      'INUSE_ATTRIBUTE_ERR'         => 10,
      'INVALID_STATE_ERR'           => 11,  # DOM Level 2
      'SYNTAX_ERR'                  => 12,  # DOM Level 2
      'INVALID_MODIFICATION_ERR'    => 13,  # DOM Level 2
      'NAMESPACE_ERR'               => 14,  # DOM Level 2
      'INVALID_ACCESS_ERR'          => 15,  # DOM Level 2
    }
    ExceptionTypes.each { |name,val|
      module_eval "const_set :#{name}, #{val}"
    }


    class DOMException < StandardError

      Descriptions = []   # Ruby specific
      ExceptionTypes.each { |name,val| Description[val] = name }

      def initialize(code)
        @code = code
      end

      attr_accessor :code

      def to_str   # Ruby specific
        Description[@code] or raise "invalid error code `#{@code}'"
      end

    end



    module DOMImplementation

      Features = {}
      Features.default = false

      def self.set_feature(feature, version)   # Ruby specific
        f = Features[feature]
        if f then
          f.push version unless f.include? version
        else
          Features[feature] = [version]
        end
      end

      module_eval {
        set_feature "Core", "2.0"
        set_feature "XML", "2.0"
      }


      def self.hasFeature(feature, version)
        f = Features[feature] and f.include? version
      end


      def self.createDocumentType(qname, pubid, sysid)  # DOM Level 2
        # raises INVALID_CHARACTER_ERR
        # raises NAMESPACE_ERR
        DocumentType.new qname, pubid, sysid
      end


      def self.createDocuemnt(namespace_uri, qname, doctype)  # DOM Level 2
        # raises INVALID_CHARACTER_ERR
        # raises NAMESPACE_ERR
        # raises WRONG_DOCUMENT_ERR
        Document.new namespace_uri, qname, doctype
      end

    end



    class NodeList

      def initialize(list)   # Ruby specific
        @list = list
      end

      def item(index)
        @list[index]
      end

      def length
        @list.size
      end

    end



    class NamedNodeMap

      def initialize    # Ruby specific
        @map = {}
        @freeze = false
      end

      def freeze        # Ruby specific
        @freeze = true
        self
      end

      def check_modifiable
        raise DOMException.new(NO_MODIFICATION_ALLOWED_ERR) if @freeze
      end
      private :check_modifiable


      def getNamedItem(name)
        @map[name]
      end

      


      def getNamedItem(name)
        @map[name]
      end

      def setNamedItem(node)
        check_modifiable
        # raises WRONG_DOCUMENT_ERR
        # raises INUSE_ATTRIUTE_ERR
        @map[node.nodeName] = node
      end

      def removeNamedItem(name)
        check_modifiable
        node = @map[node]
        raise DOMException.new(NOT_FOUND_ERR) unless node
        node
      end

      def getNamedItemNS(namespace_uri, localname)  # DOM Level 2
        f = @nsmap[localname] and f[localname]
      end

      def setNamedItemNS(node)  # DOM Level 2
        # raises WRONG_DOCUMENT_ERR
        # raises INUSE_ATTRIBUTE_ERR
        check_modifiable
        namespace_uri = node.namespaceURI || :default
        localname = node.localName
        map = @nsmap[localname]
        @nsmap[localname] = map = {} unless map
        map[namespace_uri] = node
      end

      def removeNamedItemNS(namespace_uri, localname)  # DOM Level 2
        


        
        raise DOMException
      end


      def item(index)
      end

      def length
        @map.size + @nsmap.size
      end








  class NamedNodeMap
    def initialize(doc)
      @ownerDocument = doc
      @hash = {}
    end
    attr_reader :hash

    def to_s
      s = ""
      @hash.each {|k,v|
        s << v.to_s
      }
      s
    end


    #DOM
    attr_reader :ownerDocument

    def getNamedItem(name)
      @hash[name]
    end

    def setNamedItem(arg)
      if not @ownerDocument.equal?(arg.ownerDocument)
        raise DOMException.new(INUSE_ATTRIBUTE_ERR)
      end
      name=arg.nodeName.dup
      if old=@hash[name]
        @hash[name]=arg
        old
      else
        @hash[name]=arg
        nil
      end
    end

    def removeNamedItem(name)
      @hash.delete(name)
    end

    def item(index)
      attr=@hash.to_a[index]
      if attr
        attr[1]
      else
        nil
      end
    end

    def length
      @hash.length
    end

    def getNamedItemNS(namespaceURI, localName)
      raise "Not Implemented"
    end

    def setNamedItemNS(arg)
      raise "Not Implemented"
    end

    def removeNamedItemNS(namespaceURI, localName)
      raise "Not Implemented"
    end

  end





    end







    class Node

      ELEMENT_NODE                = 1
      ATTRIBUTE_NODE              = 2
      TEXT_NODE                   = 3
      CDATA_SECTION_NODE          = 4
      ENTITY_REFERENCE_NODE       = 5
      ENTITY_NODE                 = 6
      PROCESSING_INSTRUCTION_NODE = 7
      COMMENT_NODE                = 8
      DOCUMENT_NODE               = 9
      DOCUMENT_TYPE_NODE          = 10
      DOCUMENT_FRAGMENT_NODE      = 11
      NOTATION_NODE               = 12

      def nodeName
      end

      def nodeValue
        raise DOMException
      end

      def nodeValue=(arg)
        raise DOMException
      end

      def nodeType
      end

      def parentNode
      end

      def childNodes
      end

      def firstChild
      end

      def lastChild
      end

      def previousSibling
      end

      def nextSibling
      end

      def attributes
      end

      def ownerDocument  # DOM Level 2
      end

      def insertBefore(newchild, refchild)  # DOM Level 2
        raise DOMException
      end

      def replaceChild(newchild, oldchild)  # DOM Level 2
        raise DOMException
      end

      def removeChild(oldchild)  # DOM Level 2
        raise DOMException
      end

      def appendChild(newchild)  # DOM Level 2
        raise DOMException
      end

      def hasChildNodes  # DOM Level 2
      end

      def cloneNode(deep)  # DOM Level 2
      end

      def normalize  # Modified in DOM Level 2
      end

      def isSupported(feature, version)  # DOM Level 2
      end

      def namespaceURI  # DOM Level 2
      end

      def prefix   # DOM Level 2
      end

      def prefix=(arg)  # DOM Level 2
        raise DOMException
      end

      def localName  # DOM Level 2
      end

      def hasAttributes  # DOM Level 2
      end

    end


    class CharacterData < Node

      def data
        raise DOMException
      end

      def data=(arg)
        raise DOMException
      end

      def langth
      end

      def substringData(offset, count)
        raise DOMException
      end

      def appendData(arg)
        raise DOMException
      end

      def insertData(offset, arg)
        raise DOMException
      end

      def deleteData(offset, count)
        raise DOMException
      end

      def replaceData(offset, count, arg)
        raies DOMException
      end

    end


    class Attr < Node

      def name
      end

      def specified
      end

      def value
      end

      def value=(arg)
        raise DOMException
      end

      def ownerElement  # DOM Level 2
      end

    end



    class Element < Node

      def tagName
      end

      def getAttribute(name)
      end

      def setAttribute(name, value)
        raise DOMException
      end

      def removeAttribute(name)
        raise DOMException
      end

      def getElementsByTagName(name)
      end

      def getAttributeNS(namespace_uri, localname)  # DOM Level 2
      end

      def setAttributeNS(namespace_uri, qname, value)  # DOM Level 2
        raise DOMException
      end

      def removeAttributeNS(namespace_uri, localname)  # DOM Level 2
        raise DOMException
      end

      def getAttributeNodeNS(namespace_uri, localname)    # DOM Level 2
      end

      def setAttributeNodeNS(newattr)  # DOM Level 2
        raise DOMException
      end

      def getElementsByTagNameNS(namespace_uri, localname)   # DOM Level 2
      end

      def hasAttribute(name)    # DOM Level 2
      end

      def hasAttributeNS(namespace_uri, localname)  # DOM Level 2
      end

    end


    class Text < CharacterData

      def splitText(offset)
        raise DOMException
      end

    end


    class Comment < CharacterData
    end


    class CDATASection < Text  # feature "XML"
    end

    class DocumentType < Node  # feature "XML"

      def initialize(qname, pubid, sysid)   # Ruby specific
        # raises INVALID_CHARACTER_ERR
        # raises NAMESPACE_ERR
      end


      def name
      end

      def entities
      end

      def notations
      end

      def publicId
      end

      def systemId
      end

      def internalSubset
      end

    end

    class Notation < Node  # feature "XML"

      def publicId
      end

      def systemId
      end

    end

    class Entity < Node   # feature "XML"

      def publicId
      end

      def systemId
      end

      def notationName
      end

    end


    class EntityReference < Node   # feature "XML"
    end


    class Processinginstruction < Node   # feature "XML"

      def target
      end

      def data
      end

      def data=(arg)
        raise DOMException
      end

    end



    class DocumentFragment < Node
    end



    class Document < Node

      def initialize(namespace_uri, qname, doctype)
        # raises INVALID_CHARACTER_ERR
        # raises NAMESPACE_ERR
        # raises WRONG_DOCUMENT_ERR
      end


      def doctype
      end

      def implementation
      end

      def documentElement
      end

      def createElement(tagname)
        raise DOMException
      end

      def createDocumentFragment
      end

      def createTextNode(data)
      end

      def createComment(data)
      end

      def createCDATASection(data)
        raise DOMException
      end

      def createProcessingInstruction(target, data)
        raise DOMException
      end

      def createAttribute(name)
        raise DOMException
      end

      def createEntityReference(name)
        raise DOMException
      end

      def getElementsByTagName(tagname)
      end

      def importNode(imported_node, deep)  # DOM Level 2
        raise DOMException
      end

      def createElementNS(namespace_uri, qname)  # DOM Level 2
        raise DOMException
      end

      def createAttributeNS(namespace_uri, qname)  # DOM Level 2
        raise DOMException
      end

      def getElementsByTagNameNS(namespace_uri, localname)  # DOM Level 2
      end

      def getElementById(element_id)  # DOM Level 2
      end

    end


  end

end
