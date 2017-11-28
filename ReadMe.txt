PowerShell WOL

Send Magic Packet

Usage...
    .\SendWOL.ps1 -MacAddress Terget Mac Address -NetworkAddress Terget Network Address

    Options:
        -MacAddress
            Terget MAC Address( "-" or ":" )

        -NetworkAddress
            Terget Network/CIDR

        -SubnetMask
            Subnet Mask

        -Port
            Terget UDP port number(default 7)

        -NoLog
            Log not output

    e.g.
        .\SendWOL.ps1 02-15-90-CA-0F-2A 192.168.0.15/24
        .\SendWOL.ps1 02-15-90-CA-0F-2A 192.168.0.15 255.255.255.0
