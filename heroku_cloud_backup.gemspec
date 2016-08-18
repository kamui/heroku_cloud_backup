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
  s.description = %q{PG backups into the cloud with fog}
  s.license       = "MIT"

  s.rubyforge_project = "heroku_cloud_backup"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.
                      split("\n").
                      map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'fog', '>= 1.6.0'
  s.add_dependency 'netrc', '0.10.3'
  s.add_dependency 'rest-client', '1.6.8'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
end
