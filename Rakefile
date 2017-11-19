# -*- encoding: utf-8 -*-
$:.unshift File.expand_path("../lib", __FILE__)
require 'shellwords'
require 'benchmark'

RUBYGEMS_REPO = File.expand_path("tmp/rubygems")
CARAT_SPEC = Gem::Specification.load("bundler.gemspec")

def safe_task(&block)
  yield
  true
rescue
  false
end

# Benchmark task execution
module Rake
  class Task
    alias_method :real_invoke, :invoke

    def invoke(*args)
      time = Benchmark.measure(@name) do
        real_invoke(*args)
      end
      puts "#{@name} ran for #{time}"
    end
  end
end

def clean_files(files, regex, replacement = '')
  files.each do |file|
    contents = File.read(file)
    contents.gsub!(regex, replacement)
    File.open(file, 'w') { |f| f << contents }
  end
end

namespace :molinillo do
  task :namespace do
    files = Dir.glob('lib/bundler/vendor/molinillo*/**/*.rb')
    clean_files(files, 'Molinillo', 'Carat::Molinillo')
    clean_files(files, /require (["'])molinillo/, 'require \1bundler/vendor/molinillo/lib/molinillo')
  end

  task :clean do
    files = Dir.glob('lib/bundler/vendor/molinillo*/*', File::FNM_DOTMATCH).reject { |f| %(. .. lib).include? f.split('/').last }
    rm_r files
  end

  task :update, [:tag] => [] do |t, args|
    tag = args[:tag]
    Dir.chdir 'lib/bundler/vendor' do
      rm_rf 'molinillo'
      sh "curl -L https://github.com/CocoaPods/molinillo/archive/#{tag}.tar.gz | tar -xz"
      sh "mv Molinillo-* molinillo"
    end
    Rake::Task['molinillo:namespace'].invoke
    Rake::Task['molinillo:clean'].invoke
  end
end

namespace :thor do
  task :namespace do
    files = Dir.glob('lib/bundler/vendor/thor*/**/*.rb')
    clean_files(files, 'Thor', 'Carat::Thor')
    clean_files(files, /require (["'])thor/, 'require \1bundler/vendor/thor/lib/thor')
    clean_files(files, /(autoload\s+[:\w]+,\s+["'])(thor[\w\/]+["'])/, '\1bundler/vendor/thor/lib/\2')
  end

  task :clean do
    files = Dir.glob('lib/bundler/vendor/thor*/*', File::FNM_DOTMATCH).reject { |f| %(. .. lib).include? f.split('/').last }
    rm_r files
  end

  task :update, [:tag] => [] do |t, args|
    tag = args[:tag]
    Dir.chdir 'lib/bundler/vendor' do
      rm_rf 'thor'
      sh "curl -L https://github.com/erikhuda/thor/archive/#{tag}.tar.gz | tar -xz"
      sh "mv thor-* thor"
    end
    Rake::Task['thor:namespace'].invoke
    Rake::Task['thor:clean'].invoke
  end
end

namespace :spec do
  desc "Ensure spec dependencies are installed"
  task :deps do
    deps = Hash[CARAT_SPEC.development_dependencies.map do |d|
      [d.name, d.requirement.to_s]
    end]

    # JRuby can't build ronn or rdiscount, so we skip that
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
      deps.delete("ronn")
      deps.delete("rdiscount")
    end

    deps.sort_by{|name, _| name }.each do |name, version|
      sh "#{Gem.ruby} -S gem list -i '^#{name}$' -v '#{version}' || " \
         "#{Gem.ruby} -S gem install #{name} -v '#{version}' --no-ri --no-rdoc"
    end

    # Download and install gems used inside tests
    $LOAD_PATH.unshift("./spec")
    require 'support/rubygems_ext'
    Spec::Rubygems.setup
  end

  namespace :travis do
    task :deps do
      # Give the travis user a name so that git won't fatally error
      system "sudo sed -i 's/1000::/1000:Travis:/g' /etc/passwd"
      # Strip secure_path so that RVM paths transmit through sudo -E
      system "sudo sed -i '/secure_path/d' /etc/sudoers"
      # Install groff for the ronn gem
      sh "sudo apt-get install groff-base -y"
      sh "gem update --system 2.6.13"
      # Install the other gem deps, etc.
      Rake::Task["spec:deps"].invoke
    end
  end
end

begin
  rspec = CARAT_SPEC.development_dependencies.find{|d| d.name == "rspec" }
  gem 'rspec', rspec.requirement.to_s
  require 'rspec/core/rake_task'

  desc "Run specs"
  RSpec::Core::RakeTask.new
  task :spec => "man:build"

  namespace :spec do
    task :clean do
      rm_rf 'tmp'
    end

    desc "Run the real-world spec suite (requires internet)"
    task :realworld => ["set_realworld", "spec"]

    task :set_realworld do
      ENV['CARAT_REALWORLD_TESTS'] = '1'
    end

    desc "Run the spec suite with the sudo tests"
    task :sudo => ["set_sudo", "spec", "clean_sudo"]

    task :set_sudo do
      ENV['CARAT_SUDO_TESTS'] = '1'
    end

    task :clean_sudo do
      puts "Cleaning up sudo test files..."
      system "sudo rm -rf #{File.expand_path('../tmp/sudo_gem_home', __FILE__)}"
    end

    # Rubygems specs by version
    namespace :rubygems do
      rubyopt = ENV["RUBYOPT"]
      # When editing this list, also edit .travis.yml!
      branches = %w(master)
      releases = %w(v2.4.5 v2.6.14 v2.7.2)
      (branches + releases).each do |rg|
        desc "Run specs with Rubygems #{rg}"
        RSpec::Core::RakeTask.new(rg) do |t|
          t.rspec_opts = %w(--format documentation --color)
          t.ruby_opts  = %w(-w)
        end

        # Create tasks like spec:rubygems:v1.8.3:sudo to run the sudo specs
        namespace rg do
          task :sudo => ["set_sudo", rg, "clean_sudo"]
          task :realworld => ["set_realworld", rg]
        end

        task "clone_rubygems_#{rg}" do
          unless File.directory?(RUBYGEMS_REPO)
            system("git clone https://github.com/rubygems/rubygems.git tmp/rubygems")
          end
          hash = nil

          Dir.chdir(RUBYGEMS_REPO) do
            system("git remote update")
            if rg == "master"
              system("git checkout origin/master")
            else
              system("git checkout #{rg}") || raise("Unknown Rubygems ref #{rg}")
            end
            hash = `git rev-parse HEAD`.chomp
          end

          puts "Checked out rubygems '#{rg}' at #{hash}"
          ENV["RUBYOPT"] = "-I#{File.expand_path("tmp/rubygems/lib")} #{rubyopt}"
          puts "RUBYOPT=#{ENV['RUBYOPT']}"
        end

        task rg => ["man:build", "clone_rubygems_#{rg}"]
        task "rubygems:all" => rg
      end

      desc "Run specs under a Rubygems checkout (set RG=path)"
      RSpec::Core::RakeTask.new("co") do |t|
        t.rspec_opts = %w(--format documentation --color)
        t.ruby_opts  = %w(-w)
      end

      task "setup_co" do
        rg = File.expand_path ENV['RG']
        puts "Running specs against Rubygems in #{rg}..."
        ENV["RUBYOPT"] = "-I#{rg} #{rubyopt}"
      end

      task "co" => "setup_co"
      task "rubygems:all" => "co"
    end

    desc "Run the tests on Travis CI against a rubygem version (using ENV['RGV'])"
    task :travis do
      rg = ENV['RGV'] || raise("Rubygems version is required on Travis!")

      puts "\n\e[1;33m[Travis CI] Running bundler specs against rubygems #{rg}\e[m\n\n"
      specs = safe_task { Rake::Task["spec:rubygems:#{rg}"].invoke }

      Rake::Task["spec:rubygems:#{rg}"].reenable

      puts "\n\e[1;33m[Travis CI] Running bundler sudo specs against rubygems #{rg}\e[m\n\n"
      sudos = system("sudo -E rake spec:rubygems:#{rg}:sudo")
      # clean up by chowning the newly root-owned tmp directory back to the travis user
      system("sudo chown -R #{ENV['USER']} #{File.join(File.dirname(__FILE__), 'tmp')}")

      Rake::Task["spec:rubygems:#{rg}"].reenable

      puts "\n\e[1;33m[Travis CI] Running bundler real world specs against rubygems #{rg}\e[m\n\n"
      realworld = safe_task { Rake::Task["spec:rubygems:#{rg}:realworld"].invoke }

      {"specs" => specs, "sudo" => sudos, "realworld" => realworld}.each do |name, passed|
        if passed
          puts "\e[0;32m[Travis CI] #{name} passed\e[m"
        else
          puts "\e[0;31m[Travis CI] #{name} failed\e[m"
        end
      end

      unless specs && sudos && realworld
        fail "Spec run failed, please review the log for more information"
      end
    end
  end

rescue LoadError
  task :spec do
    abort "Run `rake spec:deps` to be able to run the specs"
  end
end

begin
  require 'ronn'

  namespace :man do
    directory "lib/bundler/man"

    Dir["man/*.ronn"].each do |ronn|
      basename = File.basename(ronn, ".ronn")
      roff = "lib/bundler/man/#{basename}"

      file roff => ["lib/bundler/man", ronn] do
        sh "#{Gem.ruby} -S ronn --roff --pipe #{ronn} > #{roff}"
      end

      file "#{roff}.txt" => roff do
        sh "groff -Wall -mtty-char -mandoc -Tascii #{roff} | col -b > #{roff}.txt"
      end

      task :build_all_pages => "#{roff}.txt"
    end

    desc "Build the man pages"
    task :build => "man:build_all_pages"

    desc "Clean up from the built man pages"
    task :clean do
      rm_rf "lib/bundler/man"
    end

    task(:require) { }
  end

rescue LoadError
  namespace :man do
    task(:require) { abort "Install the ronn gem to be able to release!" }
    task(:build) { warn "Install the ronn gem to build the help pages" }
    task(:clean) { }
  end
end

desc "Update vendored SSL certs to match the certs vendored by Rubygems"
task :update_certs => "spec:rubygems:clone_rubygems_master" do
  require 'bundler/ssl_certs/certificate_manager'
  Carat::SSLCerts::CertificateManager.update_from!(RUBYGEMS_REPO)
end

require 'bundler/gem_tasks'
task :build => ["man:clean", "man:build"]
task :release => ["man:require", "man:clean", "man:build"]

task :default => :spec
