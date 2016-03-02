# encoding: utf-8

require 'fog'
require 'open-uri'
require "heroku"
require "heroku/client"
require "heroku/client/heroku_postgresql"
require "heroku/client/heroku_postgresql_backups"
require "heroku/jsplugin"
require 'heroku_cloud_backup/errors'
require 'heroku_cloud_backup/railtie'
require 'heroku_cloud_backup/version'

module HerokuCloudBackup
  class << self
    def execute
      log "heroku:backup started"

      backup = client.
        transfers.
        reject{|transfer| transfer[:to_type] == "pg_restore" }.
        first

      begin
        directory = connection.directories.get(bucket_name)
      rescue Excon::Errors::Forbidden
        raise HerokuCloudBackup::Errors::Forbidden.new("You do not have access to this bucket name. It's possible this bucket name is already owned by another user. Please check your credentials (access keys) or select a different bucket name.")
      end

      if !directory
        directory = connection.directories.create(key: bucket_name)
      end

      public_url = client.transfers_public_url(backup[:uuid])[:url]
      created_at = DateTime.parse backup[:created_at]
      db_name = backup[:from_name]
      name = "#{created_at.strftime('%Y-%m-%d-%H%M%S')}.dump"
      begin
        log "creating #{@backup_path}/#{db_name}/#{name}"
        directory.files.create(key: "#{backup_path}/#{db_name}/#{name}", body: open(public_url))
      rescue Exception => e
        raise HerokuCloudBackup::Errors::UploadError.new(e.message)
      end

      prune

      log "heroku:backup complete"
    end

    def connection=(connection)
      @connection = connection
    end

    def connection
      return @connection if @connection
      self.connection =
        begin
          case provider
          when 'aws'
            Fog::Storage.new(
              provider: 'AWS',
              aws_access_key_id: key1,
              aws_secret_access_key: key2,
              region: region,
            )
          when 'rackspace'
            Fog::Storage.new(
              provider: 'Rackspace',
              rackspace_username: key1,
              rackspace_api_key: key2,
              rackspace_region: region.to_sym,
            )
          when 'google'
            Fog::Storage.new(
              provider: 'Google',
              google_storage_secret_access_key: key1,
              google_storage_access_key_id: key2,
            )
          else
            raise "Your provider was invalid. Valid values are 'aws', 'rackspace', or 'google'"
          end
        rescue => error
          raise HerokuCloudBackup::Errors::ConnectionError.new("There was an error connecting to your provider. #{error}")
        end
    end

    def client
      @client ||= Heroku::Client::HerokuPostgresqlApp.new(ENV["HCB_APP_NAME"])
    end

    private

    def bucket_name
      ENV['HCB_BUCKET'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_BUCKET' config variable."))
    end

    def backup_path
      ENV['HCB_APP_NAME'] || "db"
    end

    def provider
      ENV['HCB_PROVIDER'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_PROVIDER' config variable."))
    end

    def key1
      ENV['HCB_KEY1'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_KEY1' config variable."))
    end

    def key2
      ENV['HCB_KEY2'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_KEY2' config variable."))
    end

    def region
      region =  case provider
                when 'aws'
                  'us-east-1'
                when 'rackspace'
                  'dfw'
                else
                  nil
                end
      ENV['HCB_REGION'] || region
    end

    def log(message)
      puts "[#{Time.now}] #{message}"
    end

    def prune
      number_of_files = ENV['HCB_MAX']
      if number_of_files && number_of_files.to_i > 0
        directory = connection.directories.get(bucket_name)
        files = directory.files.all(prefix: backup_path)
        file_count = 0
        files.reverse.each do |file|
          if file.key =~ Regexp.new("/#{backup_path}\/\d{4}-\d{2}-\d{2}-\d{6}\.sql\.gz$/i")
            file_count += 1
          else
            next
          end
          if file_count > number_of_files
            file.destroy
          end
        end
      end
    end
  end
end
