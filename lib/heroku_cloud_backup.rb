# encoding: utf-8

require 'aws-sdk-s3'
require 'heroku_cloud_backup/auth'
require 'heroku_cloud_backup/env'
require 'heroku_cloud_backup/errors'
require 'heroku_cloud_backup/pgapp'
require 'heroku_cloud_backup/jsplugin'
require 'heroku_cloud_backup/railtie'
require 'heroku_cloud_backup/version'

module HerokuCloudBackup
  class << self
    def execute
      log "heroku:backup started"

      backup = client.
        transfers.
        reject{ |transfer| transfer[:to_type] == "pg_restore" }.
        first

      begin
        directory = connection.bucket(bucket_name)
      rescue Excon::Errors::Forbidden
        raise HerokuCloudBackup::Errors::Forbidden.new(
          "You do not have access to this bucket name. It's possible this "\
            "bucket name is already owned by another user. Please check your "\
            "credentials (access keys) or select a different bucket name."
          )
      end

      if !directory
        directory = connection.create_bucket(bucket_name)
      end

      public_url = client.transfers_public_url(backup[:uuid])[:url]
      created_at = DateTime.parse backup[:created_at]
      db_name = backup[:from_name]
      name = "#{created_at.strftime('%Y-%m-%d-%H%M%S')}.dump"
      begin
        log "creating #{backup_path}/#{db_name}/#{name}"
        directory.put_object(
          key: "#{backup_path}/#{db_name}/#{name}",
          body: open(public_url)
        )
      rescue Exception => e
        raise HerokuCloudBackup::Errors::UploadError.new(e.message)
      end

      log "heroku:backup complete"
    end

    def connection=(connection)
      @connection = connection
    end

    def connection
      return @connection if @connection
      self.connection =
        begin
          Aws::S3::Resource.new(
            access_key_id: key1,
            secret_access_key: key2,
            region: region
          )
        rescue => error
          raise HerokuCloudBackup::Errors::ConnectionError.new(
            "There was an error connecting to AWS. #{error}"
          )
        end
    end

    def client
      begin
        @client ||= HerokuCloudBackup::PGApp.new(ENV["HCB_APP_NAME"])
      rescue Exception => e
        raise HerokuCloudBackup::Errors::NotFound.new(
          "Please provide a 'HCB_APP_NAME' config variable."
        )
      end
    end

    private

    def bucket_name
      begin
        ENV['HCB_BUCKET']
      rescue Exception => e
        raise HerokuCloudBackup::Errors::NotFound.new(
          "Please provide a 'HCB_BUCKET' config variable."
        )
      end
    end

    def backup_path
      begin
        ENV['HCB_APP_NAME']
      rescue Exception => e
        raise HerokuCloudBackup::Errors::NotFound.new(
          "Please provide a 'HCB_APP_NAME' config variable."
        )
      end
    end

    def key1
      begin
        ENV['HCB_KEY1']
      rescue Exception => e
        raise HerokuCloudBackup::Errors::NotFound.new(
          "Please provide a 'HCB_KEY1' config variable."
        )
      end
    end

    def key2
      begin
        ENV['HCB_KEY2']
      rescue Exception => e
        raise HerokuCloudBackup::Errors::NotFound.new(
          "Please provide a 'HCB_KEY2' config variable."
        )
      end
    end

    def region
      ENV['HCB_REGION'] || 'us-east-1'
    end

    def log(message)
      puts "[#{Time.now}] #{message}"
    end
  end
end
