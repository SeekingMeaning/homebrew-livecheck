class TransmissionCli
  livecheck :url   => "https://github.com/transmission/transmission-releases/",
            :regex => /href=.+?transmission-v?(\d+(?:\.\d+)+)\.t/i
end