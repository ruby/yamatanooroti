source 'https://rubygems.org'
require 'rbconfig'

unless RbConfig::CONFIG['host_os'].match?(/mswin|msys|mingw|cygwin|bccwin|wince|emc/)
  gem "vterm", github: "ruby/vterm-gem"
end

if Gem.win_platform?
  gem "fiddle", '>= 1.0.8' if
    (RUBY_ENGINE == "ruby" && RUBY_VERSION >= '3.4') ||
    Gem::Version.new("1.0.8") > begin
      require 'fiddle'
      Gem::Version.new(Fiddle::VERSION)
    rescue
      Gem::Version.new("0.0.0")
    end
end

# Specify your gem's dependencies in reline.gemspec
gemspec

group :development do
  gem 'rake'
  gem 'bundler'
  gem 'reline'
end
