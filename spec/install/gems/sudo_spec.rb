# frozen_string_literal: true

RSpec.describe "when using sudo", :sudo => true do
  describe "and CARAT_PATH is writable" do
    context "but CARAT_PATH/build_info is not writable" do
      before do
        carat! "config path.system true"
        subdir = system_gem_path("cache")
        subdir.mkpath
        sudo "chmod u-w #{subdir}"
      end

      it "installs" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G

        expect(out).to_not match(/an error occurred/i)
        expect(system_gem_path("cache/rack-1.0.0.gem")).to exist
        expect(the_carat).to include_gems "rack 1.0"
      end
    end
  end

  describe "and GEM_HOME is owned by root" do
    before :each do
      carat! "config path.system true"
      chown_system_gems_to_root
    end

    it "installs" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
        gem "thin"
      G

      expect(system_gem_path("gems/rack-1.0.0")).to exist
      expect(system_gem_path("gems/rack-1.0.0").stat.uid).to eq(0)
      expect(the_carat).to include_gems "rack 1.0"
    end

    it "installs rake and a gem dependent on rake in the same session" do
      gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rake"
          gem "another_implicit_rake_dep"
      G
      carat "install"
      expect(system_gem_path("gems/another_implicit_rake_dep-1.0")).to exist
    end

    it "installs when CARAT_PATH is owned by root" do
      carat_path = tmp("owned_by_root")
      FileUtils.mkdir_p carat_path
      sudo "chown -R root #{carat_path}"

      ENV["CARAT_PATH"] = carat_path.to_s
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
      G

      expect(carat_path.join("gems/rack-1.0.0")).to exist
      expect(carat_path.join("gems/rack-1.0.0").stat.uid).to eq(0)
      expect(the_carat).to include_gems "rack 1.0"
    end

    it "installs when CARAT_PATH does not exist" do
      root_path = tmp("owned_by_root")
      FileUtils.mkdir_p root_path
      sudo "chown -R root #{root_path}"
      carat_path = root_path.join("does_not_exist")

      ENV["CARAT_PATH"] = carat_path.to_s
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
      G

      expect(carat_path.join("gems/rack-1.0.0")).to exist
      expect(carat_path.join("gems/rack-1.0.0").stat.uid).to eq(0)
      expect(the_carat).to include_gems "rack 1.0"
    end

    it "installs extensions/ compiled by RubyGems 2.2", :rubygems => "2.2" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "very_simple_binary"
      G

      expect(system_gem_path("gems/very_simple_binary-1.0")).to exist
      binary_glob = system_gem_path("extensions/*/*/very_simple_binary-1.0")
      expect(Dir.glob(binary_glob).first).to be
    end
  end

  describe "and CARAT_PATH is not writable" do
    before do
      sudo "chmod ugo-w #{default_carat_path}"
    end

    it "installs" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
      G

      expect(default_carat_path("gems/rack-1.0.0")).to exist
      expect(the_carat).to include_gems "rack 1.0"
    end

    it "cleans up the tmpdirs generated" do
      require "tmpdir"
      Dir.glob("#{Dir.tmpdir}/carat*").each do |tmpdir|
        FileUtils.remove_entry_secure(tmpdir)
      end

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      tmpdirs = Dir.glob("#{Dir.tmpdir}/carat*")

      expect(tmpdirs).to be_empty
    end
  end

  describe "and GEM_HOME is not writable" do
    it "installs" do
      carat! "config path.system true"
      gem_home = tmp("sudo_gem_home")
      sudo "mkdir -p #{gem_home}"
      sudo "chmod ugo-w #{gem_home}"

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", '1.0'
      G

      carat :install, :env => { "GEM_HOME" => gem_home.to_s, "GEM_PATH" => nil }
      expect(gem_home.join("bin/rackup")).to exist
      expect(the_carat).to include_gems "rack 1.0", :env => { "GEM_HOME" => gem_home.to_s, "GEM_PATH" => nil }
    end
  end

  describe "and root runs install" do
    let(:warning) { "Don't run Carat as root." }

    before do
      gemfile %(source "file://#{gem_repo1}")
    end

    it "warns against that" do
      carat :install, :sudo => true
      expect(out).to include(warning)
    end

    context "when ENV['CARAT_SILENCE_ROOT_WARNING'] is set" do
      it "skips the warning" do
        carat :install, :sudo => :preserve_env, :env => { "CARAT_SILENCE_ROOT_WARNING" => true }
        expect(out).to_not include(warning)
      end
    end

    context "when silence_root_warning = false" do
      it "warns against that" do
        carat :install, :sudo => true, :env => { "CARAT_SILENCE_ROOT_WARNING" => "false" }
        expect(out).to include(warning)
      end
    end
  end
end
