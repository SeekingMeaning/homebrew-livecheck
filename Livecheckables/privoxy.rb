class Privoxy
  livecheck :url => "https://www.privoxy.org/feeds/privoxy-releases.xml",
            :regex => /privoxy-([0-9\.]+)-stable-src\./
end
