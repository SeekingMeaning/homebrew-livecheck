class Logcheck
  livecheck do
    url "https://packages.debian.org/unstable/logcheck"
    regex(/logcheck[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end
end
