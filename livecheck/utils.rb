def checkable_urls(cask)
  urls = []
  urls << cask.url.to_s
  urls << cask.homepage if cask.homepage
  urls.compact
end

def cask_name(cask)
  Homebrew.args.full_name? ? cask.full_name : cask
end
