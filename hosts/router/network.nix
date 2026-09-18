_: {
  dotfiles.router = {
    wan = {
      interface = "enp0s25";
      addresses = [
        "115.145.150.182"
        "115.145.150.193"
        "115.145.150.204"
        "115.145.150.203"
        "115.145.150.202"
        "115.145.150.201"
        "115.145.150.200"
        "115.145.150.199"
        "115.145.150.198"
        "115.145.150.197"
        "115.145.150.196"
        "115.145.150.195"
        "115.145.150.194"
      ];
      prefixLength = 24;
      gateway = "115.145.150.1";
    };

    lan = {
      interface = "enp5s0";
      address = "10.0.0.1";
      prefixLength = 16;
      cidr = "10.0.0.0/16";
      netmask = "255.255.0.0";
      domain = "home.arpa";
      dhcpPool = {
        start = "10.0.0.17";
        end = "10.0.255.239";
      };
    };

    cloudflare = {
      mesh.instance = "scg-skku-router";
      officeDetection = {
        address = "10.255.0.1";
        cidr = "10.255.0.1/32";
        port = 10443;
      };
    };
  };
}
