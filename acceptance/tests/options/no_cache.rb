# This test is intended to verify that the `--no-cache` command line flag will
# cause the cache to be ignored. During a run with this flag, the cache will neither
# be queried nor refreshed.
test_name "--no-cache command-line option causes the fact cache to be ignored" do
  require 'facter/acceptance/user_fact_utils'
  extend Facter::Acceptance::UserFactUtils

  # the kernel fact should be resolvable on ALL systems
  cached_fact_name = "kernel"

  config = <<-FILE
  cli : { debug : true }
  facts : { ttls : [ { "kernel" : 30 minutes } ] }
  FILE

  agents.each do |agent|
    kernel_version = on(agent, facter('kernelmajversion')).stdout.chomp.to_f
    config_dir = get_default_fact_dir(agent['platform'], kernel_version)
    config_file = File.join(config_dir, "facter.conf")

    cached_facts_dir = get_cached_facts_dir(agent['platform'], kernel_version)
    cached_fact_file = File.join(cached_facts_dir, cached_fact_name)

    teardown do
      on(agent, "rm -rf '#{config_dir}'", :acceptable_exit_codes => [0,1])
      on(agent, "rm -rf '#{cached_facts_dir}'", :acceptable_exit_codes => [0,1])
    end

    step "Agent #{agent}: create config file in default location" do
      on(agent, "mkdir -p '#{config_dir}'")
      create_remote_file(agent, config_file, config)
    end

    step "facter should not cache facts when --no-cache is specified" do
      on(agent, facter("--no-cache")) do
        assert_no_match(/caching/, stderr, "facter should not have tried to cache any facts")
      end
    end

    step "facter should not load facts from the cache when --no-cache is specified" do
      # clear the fact cache
      on(agent, "rm -rf '#{cached_facts_dir}'", :acceptable_exit_codes => [0,1])

      # run once to cache the kernel fact
      on(agent, facter(""))

      on(agent, "cat #{cached_fact_file}", :acceptable_exit_codes => [0]) do
        assert_match(/#{cached_fact_name}/, stdout, "Expected cached fact file to contain fact information")
      end

      on(agent, facter("--no-cache")) do
        assert_no_match(/loading cached values for .+ fact/, stderr, "facter should not have tried to load any cached facts")
      end
    end

    step "facter should not refresh an expired cache when --no-cache is specified" do
      # clear the fact cache
      on(agent, "rm -rf '#{cached_facts_dir}'", :acceptable_exit_codes => [0,1])

      # run once to cache the kernel fact
      on(agent, facter(""))

      # update the modify time on the new cached fact to prompt a refresh
      on(agent, "touch -mt 0301010000 '#{cached_fact_file}'")

      on(agent, facter("--no-cache")) do
        assert_no_match(/caching/, stderr, "facter should not have tried to refresh the cache")
      end
    end
  end
end
