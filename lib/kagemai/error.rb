=begin
  error.rb - error classes
=end

module Kagemai
  class Error < RuntimeError; end
  class InitializeError < Error; end;
  class ParameterError < Error; end;
  class ConfigError < Error; end;
  class NoSuchElementError < Error; end
  class NoSuchTempalteError < Error; end
  class RepositoryError < Error; end
  class AuthorizationError < Error; end
  class NoSuchResourceError < Error; end
  class SecurityError < Error; end
  class InvalidOperationError < Error; end
  class InvalidHeaderError < Error; end
  class MailError < Error; end  
  class InvalidMailError < Error; end
  class SpamError < Error; end
end
