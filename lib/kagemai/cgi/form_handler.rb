=begin
  form_handler.rb - module for check form values
=end

require 'kagemai/mail/mail'
require 'kagemai/message'

module Kagemai
  module AdminAuthorization
    def check_authorization()
      unless Mode::ADMIN.current?
        raise AuthorizationError, 'Authorization required for this operation.'
      end
    end
  end
  
  class ElementType
    def validate(cgi)
      value = cgi.get_param(@id, default())
      result = true
      if value then
        if email_check && !FormHandler.valid_email_address?(value) then
          result = :err_invalid_email_address
        elsif max_size && max_size < value.size then
          result = :err_exceed_max_size
        end
      else
        result = :err_required
      end
      result
    end    
  end
  
  class DateElementType
    def validate(cgi)
      value = cgi.get_param(@id, default())
      begin
        value.to_s.empty? || Date.parse(value)
        true
      rescue ArgumentError
        :err_invalid_date
      end
    end
  end
  
  module FormHandler
    class FormErrors
      def initialize(errors = {})
        @errors = errors
      end

      def has_id?(id)
        @errors.find{|key, earray| earray.include?(id)} != nil
      end

      def tag_class(id)
        has_id?(id) ? 'class="error"' : ''
      end

      def empty?
        @errors.empty?
      end

      def each(&block)
        @errors.each(&block)
      end
    end

    def init_form_handler()
      @errors = {}
    end
    attr_reader :errors

    
    SAVE_OPTIONS = %w(allow_cookie email_notification)
    def save_values(report_type, attachments)
      message = Message.new(report_type)
      report_type.each do |etype|
        unless etype.kind_of?(FileElementType)
          value = @cgi.get_param(etype.id, etype.default)
          message[etype.id] = value
          @session[etype.id] = value
        else
          if attachments[etype.id] then
            message.element(etype.id).add_fileinfo(attachments[etype.id])
          end
        end
      end
      
      SAVE_OPTIONS.each do |option|
        @session[option] = @cgi.get_param(option)
      end
      message
    end
    
    def restore_values(report_type)
      report_type.each do |etype|
        unless etype.kind_of?(FileElementType)
          @cgi.set_param(etype.id, @session[etype.id]) unless @session[etype.id].to_s.empty?
          @session[etype.id] = nil
        end
      end
      
      SAVE_OPTIONS.each do |option|
        @cgi.set_param(option, @session[option]) unless @session[option].to_s.empty?
        @session[option] = nil
      end
    end
    
    def validate_message_form(report_type)
      report_type.each do |etype|
        result = etype.validate(@cgi)
        unless result == true then
          add_error(result, etype.id)
        end
      end
      @errors.empty?
    end
    
    def error_id?(id)
      @errors.find{|key, earray| earray.include?(id)} != nil
    end
    
    def valid_form?()
      @errors.empty?
    end
    
    def tag_class(id)
      error_id?(id) ? 'class="error"' : ''
    end
    
    def validate_required_value(id)
      unless @cgi.get_param(id) then
        add_error(:err_required, id)
        return false
      end
      true
    end
    
    def validate_email_address(id)
      address = @cgi.get_param(id)
      if address && valid_email_address?(address)
        return true
      else
        add_error(:err_invalid_email_address, id)
        return false
      end
    end
    
    def validate_int_value(id)
      value = @cgi.get_param(id)
      if value && /[^\d]/ =~ value then
        add_error(:err_invalid_int_value, id)
        return false
      end
      true
    end
    
    def valid_email_address?(address)
      RMail::Address.validate(address)
    end
    module_function :valid_email_address?
    
    def add_error(key, value)
      unless @errors.has_key?(key) then
        @errors[key] = []
      end
      @errors[key] << value
    end
    protected :add_error
    
    NEW_REPORT_FORM  = 'new report form'
    ADD_MESSAGE_FORM = 'add message form'
    
    def start_form(form_id)
      @session['form'] = form_id
    end
    
    def is_double_post?(form_id)
      result = !@session.new_session && @session['form'] != form_id
      @session['form'] = nil
      result
    end
    
    def double_post_error_result()
      return ActionResult.new(MessageBundle[:title_post_error],
                              header(), 
                              MessageBundle[:err_double_post], 
                              footer(), 
                              @css_url, 
                              @lang,
                              @charset)
    end
  end
end
