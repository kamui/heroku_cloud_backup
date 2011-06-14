require 'fog'
require 'open-uri'
require "heroku"
require "pgbackups/client"
require 'heroku_cloud_backup/errors'
require 'heroku_cloud_backup/railtie'
require 'heroku_cloud_backup/version'

module HerokuCloudBackup
  class << self

    def log(message)
      puts "[#{Time.now}] #{message}"
    end

    def backups_url
      ENV["PGBACKUPS_URL"]
    end

    def client
      @client ||= PGBackups::Client.new(ENV["PGBACKUPS_URL"])
    end

    def databases
      if db = ENV["HEROKU_BACKUP_DATABASES"]
        db.split(",").map(&:strip)
      else
        ["DATABASE_URL"]
      end
    end

    def backup_name(to_url)
      # translate s3://bucket/email/foo/bar.dump => foo/bar
      parts = to_url.split('/')
      parts.slice(4..-1).join('/').gsub(/\.dump$/, '')
    end

    def execute
      log "heroku:backup started"

      @bucket_name = ENV['HCB_BUCKET'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_BUCKET' config variable."))
      @backup_path = ENV['HCB_PREFIX'] || "db"
      @provider = ENV['HCB_PROVIDER'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_PROVIDER' config variable."))
      @key1 = ENV['HCB_KEY1'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_KEY1' config variable."))
      @key2 = ENV['HCB_KEY2'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_KEY2' config variable."))

      b = client.get_latest_backup
      raise HerokuCloudBackup::Errors::NoBackups.new("You don't have any pgbackups. Please run heroku pgbackups:capture first.") if b.empty?

      begin
        case @provider
          when 'aws'
            @connection = Fog::Storage.new(
              :provider => 'AWS',
              :aws_access_key_id     => @key1,
              :aws_secret_access_key => @key2
            )
          when 'rackspace'
            @connection = Fog::Storage.new(
              :provider => 'Rackspace',
              :rackspace_username => @key1,
              :rackspace_api_key  => @key2
            )
          when 'google'
            @connection = Fog::Storage.new(
              :provider => 'Google',
              :google_storage_secret_access_key => @key1,
              :google_storage_access_key_id     => @key2
            )
        else
          raise HerokuCloudBackup::Errors::InvalidProvider.new("Your provider was invalid. Valid values are 'aws', 'rackspace', or 'google'")
        end
      rescue
        raise HerokuCloudBackup::Errors::ConnectionError.new("There was an error connecting to your provider.")
      end

      begin
        directory = @connection.directories.get(@bucket_name)
      rescue Excon::Errors::Forbidden
        raise HerokuCloudBackup::Errors::Forbidden.new("You do not have access to this bucket name. It's possible this bucket name is already owned by another user. Please check your credentials (access keys) or select a different bucket name.")
      end

      if !directory
        directory = @connection.directories.create(:key => @bucket_name)
      end

      public_url = b["public_url"]
      created_at = DateTime.parse b["created_at"]
      db_name = b["from_name"]
      name = "#{created_at.strftime('%Y-%m-%d-%H%M%S')}.dump"
      begin
        directory.files.create(:key => "#{@backup_path}/#{b["from_name"]}/#{name}", :body => open(public_url))
      rescue Exception => e
        raise HerokuCloudBackup::Errors::UploadError.new(e.message)
      end

      prune

      log "heroku:backup complete"
    end

    private

    def prune
      number_of_files = ENV['HCB_MAX']
      if number_of_files && number_of_files.to_i > 0
        directory = @connection.directories.get(@bucket_name)
        files = directory.files.all(:prefix => @backup_path)
        file_count = 0
        files.reverse.each do |file|
          if file.key =~ Regexp.new("/#{@backup_path}\/\d{4}-\d{2}-\d{2}-\d{6}\.sql\.gz$/i")
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