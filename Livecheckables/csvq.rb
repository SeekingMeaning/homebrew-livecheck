class Csvq
  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end
end
