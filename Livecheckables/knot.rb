class Knot
  livecheck do
    url "https://secure.nic.cz/files/knot-dns/"
    regex(/href=.*?knot-v?(\d+(?:\.\d+)+)\.t/i)
  end
end
