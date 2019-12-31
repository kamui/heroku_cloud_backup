# encoding: utf-8

$:.push File.expand_path("../lib", __FILE__)
require "heroku_cloud_backup/version"

Gem::Specification.new do |s|
  s.name        = "heroku_cloud_backup"
  s.version     = HerokuCloudBackup::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jack Chu", "Brian Gracie", "Daniel Musekamp"]
  s.email       = [
                    "jack@jackchu.com",
                    "bgracie@gmail.com",
                    "dh.musekamp@gmail.com"
                  ]
  s.homepage    = "https://github.com/pathwaysmedical/heroku_cloud_backup"
  s.summary     = %q{Backup pg dumps to the cloud}
  s.description = %q{PG backups AWS S3 with aws-sdk-s3}
  s.license     = "MIT"

  s.files         = `git ls-files`.split("\n")
  s.executables   = `git ls-files -- bin/*`.
                      split("\n").
                      map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'aws-sdk-s3', '~> 1'
  s.add_dependency 'netrc', '~> 0.11'
  s.add_dependency 'rest-client', '~> 2.0'
end
