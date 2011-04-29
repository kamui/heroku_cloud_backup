module HerokuCloudBackup
  module Errors
    class Error < StandardError; end
    class NotFound < HerokuCloudBackup::Errors::Error; end
    class InvalidProvider < HerokuCloudBackup::Errors::Error; end
    class ConnectionError < HerokuCloudBackup::Errors::Error; end
  end
end
