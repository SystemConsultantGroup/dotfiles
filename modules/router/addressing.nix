{
  officeLan = {
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

  officeDetection = {
    address = "10.255.0.1";
    cidr = "10.255.0.1/32";
    port = 10443;
  };
}
