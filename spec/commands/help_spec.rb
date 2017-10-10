# frozen_string_literal: true

RSpec.describe "carat help" do
  # RubyGems 1.4+ no longer load gem plugins so this test is no longer needed
  it "complains if older versions of carat are installed", :rubygems => "< 1.4" do
    system_gems "carat-0.8.1"

    carat "help"
    expect(err).to include("older than 0.9")
    expect(err).to include("running `gem cleanup carat`.")
  end

  it "uses mann when available" do
    with_fake_man do
      carat "help gemfile"
    end
    expect(out).to eq(%(["#{root}/man/gemfile.5"]))
  end

  it "prefixes carat commands with carat- when finding the groff files" do
    with_fake_man do
      carat "help install"
    end
    expect(out).to eq(%(["#{root}/man/carat-install.1"]))
  end

  it "simply outputs the txt file when there is no man on the path" do
    with_path_as("") do
      carat "help install"
    end
    expect(out).to match(/CARAT-INSTALL/)
  end

  it "still outputs the old help for commands that do not have man pages yet" do
    carat "help version"
    expect(out).to include("Prints the carat's version information")
  end

  it "looks for a binary and executes it with --help option if it's named carat-<task>" do
    File.open(tmp("carat-testtasks"), "w", 0o755) do |f|
      f.puts "#!/usr/bin/env ruby\nputs ARGV.join(' ')\n"
    end

    with_path_added(tmp) do
      carat "help testtasks"
    end

    expect(exitstatus).to be_zero if exitstatus
    expect(out).to eq("--help")
  end

  it "is called when the --help flag is used after the command" do
    with_fake_man do
      carat "install --help"
    end
    expect(out).to eq(%(["#{root}/man/carat-install.1"]))
  end

  it "is called when the --help flag is used before the command" do
    with_fake_man do
      carat "--help install"
    end
    expect(out).to eq(%(["#{root}/man/carat-install.1"]))
  end

  it "is called when the -h flag is used before the command" do
    with_fake_man do
      carat "-h install"
    end
    expect(out).to eq(%(["#{root}/man/carat-install.1"]))
  end

  it "is called when the -h flag is used after the command" do
    with_fake_man do
      carat "install -h"
    end
    expect(out).to eq(%(["#{root}/man/carat-install.1"]))
  end

  it "has helpful output when using --help flag for a non-existent command" do
    with_fake_man do
      carat "instill -h"
    end
    expect(out).to include('Could not find command "instill".')
  end

  it "is called when only using the --help flag" do
    with_fake_man do
      carat "--help"
    end
    expect(out).to eq(%(["#{root}/man/carat.1"]))

    with_fake_man do
      carat "-h"
    end
    expect(out).to eq(%(["#{root}/man/carat.1"]))
  end
end
