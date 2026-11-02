{ config, ... }:
{
  # Publish this upstream printer on the office LAN, without reflecting mDNS
  # between networks. TXT capabilities match the printer's native DNS-SD data;
  # recheck them after printer/firmware changes.
  services.avahi = {
    enable = true;
    allowInterfaces = [ config.dotfiles.router.lan.interface ];
    ipv4 = true;
    ipv6 = false;
    reflector = false;
    wideArea = false;
    openFirewall = false;
    publish = {
      enable = true;
      addresses = false;
      userServices = false;
      hinfo = false;
      workstation = false;
      domain = false;
    };
    extraServiceFiles.office-printer = ''
      <?xml version="1.0" standalone="no"?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name>Samsung K3250 Series (SEC842519C6BAE6)</name>
        <service protocol="ipv4">
          <type>_ipp._tcp</type>
          <subtype>_universal._sub._ipp._tcp</subtype>
          <host-name>SEC842519C6BAE6.local</host-name>
          <port>631</port>
          <txt-record>txtvers=1</txt-record>
          <txt-record>qtotal=1</txt-record>
          <txt-record>rp=ipp/print</txt-record>
          <txt-record>ty=Samsung K3250 Series</txt-record>
          <txt-record>product=(Samsung K3250 Series)</txt-record>
          <txt-record>priority=51</txt-record>
          <txt-record>pdl=application/octet-stream,application/PCL,application/postscript,application/vnd.hp-PCL,application/vnd.hp-PCLXL,application/x-QPDL,application/pdf,text/plain,image/urf</txt-record>
          <txt-record>adminurl=http://SEC842519C6BAE6.local/sws/index.html</txt-record>
          <txt-record>UUID=16a65700-007c-1000-bb49-842519c6bae6</txt-record>
          <txt-record>URF=CP255,DM1,FN3,IFU0,IS1-2-19,MT1-2-3-4,OB10,PQ4,RS300,V1.4</txt-record>
          <txt-record>kind=document,envelope,label</txt-record>
          <txt-record>Color=F</txt-record>
          <txt-record>Duplex=T</txt-record>
          <txt-record>Copies=T</txt-record>
          <txt-record>Collate=F</txt-record>
          <txt-record>PaperCustom=T</txt-record>
          <txt-record>PaperMax=isoC-A2</txt-record>
        </service>
      </service-group>
    '';
  };

  # The SRV target must resolve on the LAN too; do not advertise the router's
  # address as the printer or add this mapping to ordinary unicast DNS.
  environment.etc."avahi/hosts".text = ''
    115.145.150.183 SEC842519C6BAE6.local
  '';

  networking.firewall.interfaces.${config.dotfiles.router.lan.interface}.allowedUDPPorts = [ 5353 ];
}
