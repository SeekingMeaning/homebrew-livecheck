require "cli/parser"

require_relative "../livecheck_strategy"
require_relative "../livecheck/utils"
require_relative "../livecheck/heuristic"
require_relative "../livecheck/extend/formulary"

LIVECHECKABLES_PATH = Pathname(__dir__).parent/"Livecheckables"

WATCHLIST_PATH = ENV["HOMEBREW_LIVECHECK_WATCHLIST"]
WATCHLIST_PATH ||= Pathname.new(Dir.home)/".brew_livecheck_watchlist"

module Homebrew
  module_function

  def livecheck_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `livecheck` [<casks>]

        Check for newer versions of casks from upstream.

        If no cask argument is passed, the list of casks to check is taken from `HOMEBREW_LIVECHECK_WATCHLIST`
        or `~/.brew_livecheck_watchlist`.
      EOS
      switch :verbose
      switch :quiet
      switch :debug
      switch "--full-name",
             description: "Print casks with fully-qualified names."
      flag   "--tap=",
             description: "Check the casks within the given tap, specified as <user>`/`<repo>."
      switch "--installed",
             description: "Check casks that are currently installed."
      switch "--json",
             description: "Output informations in JSON format."
      switch "--all",
             description: "Check all available casks."
      switch "--newer-only",
             description: "Show the latest version only if it's newer than the cask."
      conflicts "--debug", "--json"
      conflicts "--tap=", "--all", "--installed"
    end
  end

  def livecheck
    @args = livecheck_args.parse

    if @args.debug? && @args.verbose?
      puts ARGV.inspect
      puts @args
      puts ENV["HOMEBREW_LIVECHECK_WATCHLIST"] if ENV["HOMEBREW_LIVECHECK_WATCHLIST"].present?
    end

    if (cmd = @args.named.first)
      require?("livecheck/commands/#{cmd}") && return
    end

    casks_to_check =
      if @args.tap
        Tap.fetch(@args.tap).cask_files.map { |file| Cask::CaskLoader.load(file) }
      # elsif @args.installed?
      #   Formula.installed
      # elsif @args.all?
      #   Formula.full_names.map { |name| Formula[name] }
      elsif !@args.named.to_casks.empty?
        @args.named.to_casks
      elsif File.exist?(WATCHLIST_PATH)
        Enumerator.new do |enum|
          File.open(WATCHLIST_PATH).each do |line|
            next if line.start_with?("#")

            line.split.each do |word|
              enum.yield Cask::CaskLoader.load(word)
            end
          end
        rescue Errno::ENOENT => e
          onoe e
        end
      end
    return unless casks_to_check

    # Identify any non-homebrew/core taps in use for current casks
    non_cask_taps = {}
    casks_to_check.each do |c|
      non_cask_taps[c.tap.name] = true unless c.tap.nil? || c.tap.name == "homebrew/cask"
    end
    non_cask_taps = non_cask_taps.keys.sort

    # Load additional LivecheckStrategy files from taps
    non_cask_taps.each do |tap_name|
      tap_strategy_path = File.join(Tap.fetch(tap_name).path, "livecheck_strategy")
      Dir.glob(File.join(tap_strategy_path, "*.rb"), &method(:require)) if Dir.exist?(tap_strategy_path)
    end

    casks_checked = casks_to_check.sort_by(&:token).map.with_index do |cask, i|
      puts "\n----------\n" if @args.debug? && i.positive?
      print_latest_version cask
    rescue => e
      Homebrew.failed = true

      if @args.json?
        {
          "cask"  => cask_name(cask),
          "status"   => "error",
          "messages" => [e.to_s],
        }
      elsif !@args.quiet?
        onoe "#{Tty.blue}#{cask_name(cask)}#{Tty.reset}: #{e}"
        nil
      end
    end

    puts JSON.generate(casks_checked.compact) if @args.json?
  end

  def print_latest_version(cask)
    # if formula.deprecated? && !formula.livecheckable?
    #   if @args.json?
    #     return {
    #       "formula" => formula_name(formula),
    #       "status"  => "deprecated",
    #     }
    #   elsif !@args.quiet?
    #     puts "#{Tty.red}#{formula_name(formula)}#{Tty.reset} : deprecated"
    #     return
    #   end
    # end

    # if formula.to_s.include?("@") && !formula.livecheckable?
    #   if @args.json?
    #     return {
    #       "formula" => formula_name(formula),
    #       "status"  => "versioned",
    #     }
    #   elsif !@args.quiet?
    #     puts "#{Tty.red}#{formula_name(formula)}#{Tty.reset} : versioned"
    #     return
    #   end
    # end

    # if !formula.stable? && !formula.any_version_installed?
    #   if @args.json?
    #     return {
    #       "formula"  => formula_name(formula),
    #       "status"   => "error",
    #       "messages" => [
    #         "HEAD only formula must be installed to be livecheckable",
    #       ],
    #     }
    #   elsif !@args.quiet?
    #     puts "#{Tty.red}#{formula_name(formula)}#{Tty.reset} : " \
    #       "HEAD only formula must be installed to be livecheckable"
    #     return
    #   end
    # end

    # is_gist = formula.stable&.url&.include?("gist.github.com")
    # if formula.livecheck.skip? || is_gist
    #   skip_msg = if formula.livecheck.skip_msg.is_a?(String) &&
    #                 !formula.livecheck.skip_msg.blank?
    #     formula.livecheck.skip_msg.to_s
    #   elsif is_gist
    #     "Stable URL is a GitHub Gist"
    #   else
    #     ""
    #   end
    #
    #   if @args.json?
    #     json_hash = {
    #       "formula" => formula_name(formula),
    #       "status"  => "skipped",
    #     }
    #     json_hash["messages"] = [skip_msg] unless skip_msg.nil? || skip_msg.empty?
    #     return json_hash
    #   elsif !@args.quiet?
    #     puts "#{Tty.red}#{formula_name(formula)}#{Tty.reset} : skipped" \
    #          "#{" - #{skip_msg}" unless skip_msg.empty?}"
    #     return
    #   end
    # end

    # formula.head.downloader.shutup! unless formula.stable?

    current = cask.version # TODO: before_comma, after_colon, etc.

    version_info = latest_version(cask)
    latest = version_info.nil? ? nil : version_info["latest"]

    if latest.nil?
      if @args.json?
        return {
          "cask"     => cask_name(cask),
          "status"   => "error",
          "messages" => ["Unable to get versions"],
        }
      else
        raise TypeError, "Unable to get versions"
      end
    end

    if (m = latest.to_s.match(/(.*)-release$/)) && !current.to_s.match(/.*-release$/)
      latest = Version.new(m[1])
    end

    is_outdated = current < latest
    is_newer_than_upstream = current > latest

    cask_s = "#{Tty.blue}#{cask_name(cask)}#{Tty.reset}"

    return if @args.newer_only? && !is_outdated

    if @args.json?
      json_hash = {
        "cask"    => cask_name(cask),
        "version" => {
          "current"             => current.to_s,
          "latest"              => latest.to_s,
          "outdated"            => is_outdated,
          "newer_than_upstream" => is_newer_than_upstream,
        },
      }

      if @args.verbose?
        json_hash["meta"] = {}
        # json_hash["meta"]["livecheckable"] = formula.livecheckable?
        # json_hash["meta"]["head_only"] = !formula.stable? unless formula.stable?
        json_hash["meta"].merge!(version_info["meta"]) unless version_info.nil?
      end

      return json_hash
    end

    cask_s += " (guessed)" if @args.verbose?
    current_s =
      if is_newer_than_upstream
        "#{Tty.red}#{current}#{Tty.reset}"
      else
        current.to_s
      end
    latest_s =
      if is_outdated
        "#{Tty.green}#{latest}#{Tty.reset}"
      else
        latest.to_s
      end
    puts "#{cask_s} : #{current_s} ==> #{latest_s}"
  end
end
