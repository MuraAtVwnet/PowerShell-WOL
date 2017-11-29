PowerShell WOL

Send Magic Packet

Usage...
    .\WOL.ps1 -MacAddress Terget Mac Address(s) -NetworkAddress Terget Network Address

    Options:
        -MacAddress
            Terget MAC Address(s) ( "-" or ":" )

        -NetworkAddress
            Terget Network/CIDR

        -SubnetMask
            Subnet Mask

        -Port
            Terget UDP port number(default 7)

        -NoLog
            Log not output

    e.g.
        .\WOL.ps1 02-15-90-CA-0F-2A 192.168.0.15/24
        .\WOL.ps1 02-15-90-CA-0F-2A 192.168.0.15 255.255.255.0
        .\WOL.ps1 -NetworkAddress 192.168.0.15/24 -MacAddress 02-15-90-CA-0F-2A -NoLog

        $MacAddresses = "02-15-90-CA-0F-2A", "02-15-90-CA-0F-2B"
        .\WOL.ps1 $MacAddresses 192.168.0.15/24

Web page
    PowerShell WOL
    http://www.vwnet.jp/Windows/PowerShell/2017112801/PowerShellWOL.htm
