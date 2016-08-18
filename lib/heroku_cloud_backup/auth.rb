require 'netrc'
require 'open-uri'

module HerokuCloudBackup
  class Auth
    class << self
      attr_accessor :credentials

      def user
        get_credentials[0]
      end

      def password
        get_credentials[1]
      end

      def running_on_windows?
        RUBY_PLATFORM =~ /mswin32|mingw32/
      end

      def home_directory
        if running_on_windows?
          home = HerokuCloudBackup::Env["HOME"]
          homedrive = HerokuCloudBackup::Env["HOMEDRIVE"]
          homepath = HerokuCloudBackup::Env["HOMEPATH"]
          userprofile = HerokuCloudBackup::Env["USERPROFILE"]
          home_dir =
            if home
              home
            elsif homedrive && homepath
              homedrive + homepath
            elsif userprofile
              userprofile
            else
              raise ArgumentError.new(
                "couldn't find HOME environment -- expanding `~'"
              )
            end
          home_dir.gsub(/\\/, '/')
        else
          Dir.home
        end
      end

      private

      def get_credentials
        @credentials ||= (read_credentials || login)
      end

      def login
        HerokuCloudBackup::JSPlugin.spawn('login', '', []) or exit
        @netrc, @api, @client, @credentials = nil
        get_credentials
      end

      def read_credentials
        if ENV['HEROKU_API_KEY'] && ENV['HEROKU_API_KEY'] != ''
          ['', ENV['HEROKU_API_KEY']]
        else
          # convert legacy credentials to netrc
          if File.exists?(legacy_credentials_path)
            @api, @client = nil
            @credentials = File.read(legacy_credentials_path).split("\n")
            write_credentials
            FileUtils.rm_f(legacy_credentials_path)
          end

          # read netrc credentials if they exist
          if netrc
            netrc_host = full_host_uri.host
            # force migration of long api tokens (80 chars) to short ones (40)
            # #write_credentials rewrites both api.* and code.*
            credentials = netrc[netrc_host]
            if credentials && credentials[1].length > 40
              @credentials = [ credentials[0], credentials[1][0,40] ]
              write_credentials
            end
            netrc[netrc_host]
          end
        end
      end

      def netrc   # :nodoc:
        @netrc ||= begin
          File.exists?(netrc_path) && Netrc.read(netrc_path)
        rescue => error
          case error.message
          when /^Permission bits for/
            abort(
              "#{error.message}.\nYou should run `chmod 0600 #{netrc_path}` "/
                "so that your credentials are NOT accessible by others."
            )
          when /EACCES/
            error(
              "Error reading #{netrc_path}\n#{error.message}\nMake sure this "/
                "user can read/write this file."
            )
          else
            error(
              "Error reading #{netrc_path}\n#{error.message}\nYou may need "/
                "to delete this file and run `heroku login` to recreate it."
            )
          end
        end
      end

      def netrc_path
        default =
          begin
            File.join(
              HerokuCloudBackup::Env['NETRC'] ||
                home_directory, Netrc.netrc_filename
            )
          rescue NoMethodError # happens if old netrc gem is installed
            Netrc.default_path
          end
        # note: the ruby client tries to drop in `pwd` if home does not exist
        # but the go client does not, so we do not want the fallback logic
        encrypted = default + ".gpg"
        if File.exists?(encrypted)
          encrypted
        else
          default
        end
      end

      def write_credentials
        FileUtils.mkdir_p(File.dirname(netrc_path))
        FileUtils.touch(netrc_path)
        unless running_on_windows?
          FileUtils.chmod(0600, netrc_path)
        end
        subdomains.each do |sub|
          netrc["#{sub}.#{host}"] = self.credentials
        end
        netrc.save
      end

      def subdomains
        %w(api git)
      end

      def legacy_credentials_path
        if host == default_host
          "#{home_directory}/.heroku/credentials"
        else
          "#{home_directory}/.heroku/credentials.#{CGI.escape(host)}"
        end
      end

      def host
        ENV['HEROKU_HOST'] || default_host
      end

      def default_host
        "heroku.com"
      end

      def full_host
        (host =~ /^http/) ? host : "https://api.#{host}"
      end

      def full_host_uri
        URI.parse(full_host)
      end
    end
  end
end
