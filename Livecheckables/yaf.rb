class Yaf
  livecheck do
    url "https://tools.netsa.cert.org/yaf/download.html"
    regex(%r{/yaf[._-]v?(\d+(?:\.\d+)+)\.t}i)
  end
end
