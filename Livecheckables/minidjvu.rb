class Minidjvu
  livecheck do
    url "https://sourceforge.net/projects/minidjvu/"
    regex(%r{url=.*?/minidjvu[._-]v?((?!0\.33)\d+(?:\.\d+)+)\.t}i)
  end
end
