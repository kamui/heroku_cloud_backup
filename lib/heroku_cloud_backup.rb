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

      @bucket_name = ENV['HCB_BUCKET'] || "#{ENV['APP_NAME']}-heroku-backups"
      @backup_path = ENV['HCB_PREFIX'] || "db"
      @providers = ENV['HCB_PROVIDERS'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_PROVIDERS' config variable."))
      b = client.get_latest_backup
      raise HerokuCloudBackup::Errors::NoBackups.new("You don't have any pgbackups. Please run heroku pgbackups:capture first.") if b.empty?

      @providers.split(',').each do |provider|
        case provider
          when 'aws'
            @hcb_aws_access_key_id = ENV['HCB_AWS_ACCESS_KEY_ID'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_AWS_ACCESS_KEY_ID' config variable."))
            @hcb_aws_secret_access_key = ENV['HCB_AWS_SECRET_ACCESS_KEY'] || raise(HerokuCloudBackup::Errors::NotFound.new("Please provide a 'HCB_AWS_SECRET_ACCESS_KEY' config variable."))
            begin
              @connection = Fog::Storage.new(
                :provider => 'AWS',
                :aws_access_key_id => @hcb_aws_access_key_id,
                :aws_secret_access_key => @hcb_aws_secret_access_key
              )
            rescue
              raise HerokuCloudBackup::Errors::ConnectionError.new("There was an error connecting to your provider.")
            end
        else
          raise HerokuCloudBackup::Errors::InvalidProvider.new("One or more of your providers were invalid. Valid values are 'aws', 'rackspace', or 'google'")
        end

        directory = @connection.directories.get(@bucket_name)

        if !directory
          directory = @connection.directories.create(:key => @bucket_name)
        end

        public_url = b["public_url"]
        created_at = DateTime.parse b["created_at"]
        db_name = b["from_name"]
        name = "#{ENV['APP_NAME']}-#{created_at.strftime('%Y-%m-%d-%H%M%S')}.dump"
        begin
          directory.files.create(:key => "#{@backup_path}/#{b["from_name"]}/#{name}", :body => open(public_url))
        rescue Exception => e
          raise HerokuCloudBackup::Errors::UploadError.new(e.message)
        end
      end

      prune

      log "heroku:backup complete"
    end

    private

    def prune
      number_of_files = ENV['HCB_MAX_BACKUPS']
      if number_of_files && number_of_files.to_i > 0
        directory = @connection.directories.get(@bucket_name)
        files = directory.files.all(:prefix => @backup_path)
        file_count = 0
        files.reverse.each do |file|
          if file.key =~ Regexp.new("/#{@backup_path}\/#{ENV['APP_NAME']}-\d{4}-\d{2}-\d{2}-\d{6}\.sql\.gz$/i")
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