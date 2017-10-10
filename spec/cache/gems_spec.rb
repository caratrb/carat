# frozen_string_literal: true

RSpec.describe "carat cache" do
  shared_examples_for "when there are only gemsources" do
    before :each do
      gemfile <<-G
        gem 'rack'
      G

      system_gems "rack-1.0.0", :path => :carat_path
      carat! :cache
    end

    it "copies the .gem file to vendor/cache" do
      expect(carated_app("vendor/cache/rack-1.0.0.gem")).to exist
    end

    it "uses the cache as a source when installing gems" do
      build_gem "omg", :path => carated_app("vendor/cache")

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "omg"
      G

      expect(the_carat).to include_gems "omg 1.0.0"
    end

    it "uses the cache as a source when installing gems with --local" do
      system_gems [], :path => :carat_path
      carat "install --local"

      expect(the_carat).to include_gems("rack 1.0.0")
    end

    it "does not reinstall gems from the cache if they exist on the system" do
      build_gem "rack", "1.0.0", :path => carated_app("vendor/cache") do |s|
        s.write "lib/rack.rb", "RACK = 'FAIL'"
      end

      install_gemfile <<-G
        gem "rack"
      G

      expect(the_carat).to include_gems("rack 1.0.0")
    end

    it "does not reinstall gems from the cache if they exist in the carat" do
      system_gems "rack-1.0.0", :path => :carat_path

      gemfile <<-G
        gem "rack"
      G

      build_gem "rack", "1.0.0", :path => carated_app("vendor/cache") do |s|
        s.write "lib/rack.rb", "RACK = 'FAIL'"
      end

      carat! :install, :local => true
      expect(the_carat).to include_gems("rack 1.0.0")
    end

    it "creates a lockfile" do
      cache_gems "rack-1.0.0"

      gemfile <<-G
        gem "rack"
      G

      carat "cache"

      expect(carated_app("Gemfile.lock")).to exist
    end
  end

  context "using system gems" do
    before { carat! "config path.system true" }
    it_behaves_like "when there are only gemsources"
  end

  context "installing into a local path" do
    before { carat! "config path ./.carat" }
    it_behaves_like "when there are only gemsources"
  end

  describe "when there is a built-in gem", :ruby => "2.0" do
    before :each do
      build_repo2 do
        build_gem "builtin_gem", "1.0.2"
      end

      build_gem "builtin_gem", "1.0.2", :to_system => true do |s|
        s.summary = "This builtin_gem is carated with Ruby"
      end

      FileUtils.rm("#{system_gem_path}/cache/builtin_gem-1.0.2.gem")
    end

    it "uses builtin gems when installing to system gems" do
      carat! "config path.system true"
      install_gemfile %(gem 'builtin_gem', '1.0.2')
      expect(the_carat).to include_gems("builtin_gem 1.0.2")
    end

    it "caches remote and builtin gems" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem 'builtin_gem', '1.0.2'
        gem 'rack', '1.0.0'
      G

      carat :cache
      expect(carated_app("vendor/cache/rack-1.0.0.gem")).to exist
      expect(carated_app("vendor/cache/builtin_gem-1.0.2.gem")).to exist
    end

    it "doesn't make remote request after caching the gem" do
      build_gem "builtin_gem_2", "1.0.2", :path => carated_app("vendor/cache") do |s|
        s.summary = "This builtin_gem is carated with Ruby"
      end

      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem 'builtin_gem_2', '1.0.2'
      G

      carat "install --local"
      expect(the_carat).to include_gems("builtin_gem_2 1.0.2")
    end

    it "errors if the builtin gem isn't available to cache" do
      carat! "config path.system true"

      install_gemfile <<-G
        gem 'builtin_gem', '1.0.2'
      G

      carat :cache
      expect(exitstatus).to_not eq(0) if exitstatus
      expect(out).to include("builtin_gem-1.0.2 is built in to Ruby, and can't be cached")
    end
  end

  describe "when there are also git sources" do
    before do
      build_git "foo"
      system_gems "rack-1.0.0"

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        git "#{lib_path("foo-1.0")}" do
          gem 'foo'
        end
        gem 'rack'
      G
    end

    it "still works" do
      carat :cache

      system_gems []
      carat "install --local"

      expect(the_carat).to include_gems("rack 1.0.0", "foo 1.0")
    end

    it "should not explode if the lockfile is not present" do
      FileUtils.rm(carated_app("Gemfile.lock"))

      carat :cache

      expect(carated_app("Gemfile.lock")).to exist
    end
  end

  describe "when previously cached" do
    before :each do
      build_repo2
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
        gem "actionpack"
      G
      carat :cache
      expect(cached_gem("rack-1.0.0")).to exist
      expect(cached_gem("actionpack-2.3.2")).to exist
      expect(cached_gem("activesupport-2.3.2")).to exist
    end

    it "re-caches during install" do
      cached_gem("rack-1.0.0").rmtree
      carat :install
      expect(out).to include("Updating files in vendor/cache")
      expect(cached_gem("rack-1.0.0")).to exist
    end

    it "adds and removes when gems are updated" do
      update_repo2
      carat "update", :all => carat_update_requires_all?
      expect(cached_gem("rack-1.2")).to exist
      expect(cached_gem("rack-1.0.0")).not_to exist
    end

    it "adds new gems and dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails"
      G
      expect(cached_gem("rails-2.3.2")).to exist
      expect(cached_gem("activerecord-2.3.2")).to exist
    end

    it "removes .gems for removed gems and dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
      G
      expect(cached_gem("rack-1.0.0")).to exist
      expect(cached_gem("actionpack-2.3.2")).not_to exist
      expect(cached_gem("activesupport-2.3.2")).not_to exist
    end

    it "removes .gems when gem changes to git source" do
      build_git "rack"

      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack", :git => "#{lib_path("rack-1.0")}"
        gem "actionpack"
      G
      expect(cached_gem("rack-1.0.0")).not_to exist
      expect(cached_gem("actionpack-2.3.2")).to exist
      expect(cached_gem("activesupport-2.3.2")).to exist
    end

    it "doesn't remove gems that are for another platform" do
      simulate_platform "java" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "platform_specific"
        G

        carat :cache
        expect(cached_gem("platform_specific-1.0-java")).to exist
      end

      simulate_new_machine
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "platform_specific"
      G

      expect(cached_gem("platform_specific-1.0-#{Carat.local_platform}")).to exist
      expect(cached_gem("platform_specific-1.0-java")).to exist
    end

    it "doesn't remove gems with mismatched :rubygems_version or :date" do
      cached_gem("rack-1.0.0").rmtree
      build_gem "rack", "1.0.0",
        :path => carated_app("vendor/cache"),
        :rubygems_version => "1.3.2"
      simulate_new_machine

      carat :install
      expect(cached_gem("rack-1.0.0")).to exist
    end

    it "handles directories and non .gem files in the cache" do
      carated_app("vendor/cache/foo").mkdir
      File.open(carated_app("vendor/cache/bar"), "w") {|f| f.write("not a gem") }
      carat :cache
    end

    it "does not say that it is removing gems when it isn't actually doing so" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      carat "cache"
      carat "install"
      expect(out).not_to match(/removing/i)
    end

    it "does not warn about all if it doesn't have any git/path dependency" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      carat "cache"
      expect(out).not_to match(/\-\-all/)
    end

    it "should install gems with the name carat in them (that aren't carat)" do
      build_gem "foo-carat", "1.0",
        :path => carated_app("vendor/cache")

      install_gemfile <<-G
        gem "foo-carat"
      G

      expect(the_carat).to include_gems "foo-carat 1.0"
    end
  end
end
