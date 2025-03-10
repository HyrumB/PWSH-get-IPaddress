# https://drive.google.com/file/d/1_pqlZEOC2J6oHLWggN_v8ttMnGtvveBm/view?usp=drive_link


# declaire the class to store the ip
class Ipinfo {
    [System.Net.IPAddress]$IPaddress
    [int]$prefixlength
    [string]$interface
    [string]$AddressFamily
    [string]$macaddress

    Ipinfo([System.Net.IPAddress]$IPaddress, [int]$prefixlength, [string]$interface, [string]$AddressFamily, [string]$macaddress) {
        $this.IPaddress = $IPaddress
        $this.prefixlength = $prefixlength
        $this.interface = $interface
        $this.AddressFamily = $AddressFamily
        $this.macaddress = $macaddress
    }
}


# wrapper for the real ip functions
function Get-IPAddress {
    param(
        [string]$AddressType
    )

    # check if the variable is empty or both
    if ($AddressType -eq "" -or $AddressType -eq "both") {
        if ($IsLinux) {
            $ip = Get-LinuxIP("both")
            Write-Output $ip
        }
        elseif ($isWindows) {
            $ip = Get-WindowsIP("both")
            Write-Output $ip

        }
        else {
            Write-Warning "this OS is not suported please use windows or linux"
        }

    }

    elseif ($AddressType -eq "IPv4") {
        if ($IsLinux) {
            $ip = Get-LinuxIP("IPv4")
            Write-Output $ip
            
        }
        elseif ($isWindows) {
            Get-WindowsIP("IPV4")
        }
        else {
            Write-Warning "this OS is not suported please use windows or linux"
        }
    } 

    elseif ($AddressType -eq "IPv6") {
        if ($IsLinux) {
            $ip = Get-LinuxIP("IPv6")
            write-output $ip
        }
        elseif ($isWindows) {
            Get-WindowsIP("IPV6")
        }
        else {
            Write-Warning "this OS is not suported please use windows or linux"
        }
    }
}

# get the linux ips
function Get-LinuxIP {
    param(
        [string]$AddressType = "both" # make it default to both IPv4 and IPv6
    )

    # pwsh command substitution to collect the output of a bash command
    $ipinfo = $(ip addr)

    # send out a warning if the command fails
    if ($null -eq $ipinfo -Or $ipinfo -eq "") {
        Write-Warning "No IP information found."
        return
    }

    $ipAddresses = @() # Initialize an array to store IP information

    foreach ($line in $ipinfo) {

        # get the interface
        if ($line -like "*2:*") {
            $arr = $line -split "\s+"
            $interface = $arr[1]

        }

        # get the mac address
        elseif ($line -like "*link/ether*") {
            $arr = $line -split "\s+"
            $macaddress = $arr[2]

        }

        # get the ipv6 info
        elseif ($line -like "*inet*" -and $line -notlike "*scope host*") {
            $IParr = $line -split "\s+"
            $ipWithPrefix = $IParr[2]
            $ipSplit = $ipWithPrefix -split "/"
            $ip = $ipSplit[0]
            $prefix = $ipSplit[1]
            
            # get the ipv6 string
            if ($line -like "*inet6*") {
                if ($AddressType -eq "IPv6" -or $AddressType -eq "both") {
                    try {
                        $ipv6 = [System.Net.IPAddress]::Parse($ip)
                        $ipAddresses += [PSCustomObject]@{
                            IPAddress   = $ipv6
                            Prefix      = $prefix
                            Interface   = $interface
                            AddressType = "IPv6"
                            MACAddress  = $macaddress
                        }
                    }
                    catch {
                        Write-Warning "Failed to parse IPv6 address: $ip"
                    }
                }

            }
            
            # get the ipv4 info
            elseif ($line -like "*inet*" -and $line -notlike "*inet6*") {
                if ($AddressType -eq "IPv4" -or $AddressType -eq "both") {
                    try {
                        $ipv4 = [System.Net.IPAddress]::Parse($ip)
                        $ipAddresses += [PSCustomObject]@{
                            IPAddress   = $ipv4
                            Prefix      = $prefix
                            Interface   = $interface
                            AddressType = "IPv4"
                            MACAddress  = $macaddress
                        }

                    }
                    catch {
                        Write-Warning "Failed to parse IPv4 address: $ip"
                    }
                }
            }
        }
    }

    return $ipAddresses
}

# get the windows ips
function Get-WindowsIP {
    param(
        [string]$AddressType = "both" # Default to both IPv4 and IPv6
    )

    $ips = Get-NetIPAddress

    $ipAddresses = @() # Initialize an array to store IP information

    # Get MAC address(es)
    
    $macSting = ipconfig /all | Select-String "Physical Address"
    # remove extranious info
    $macAddresses = $macSting -replace "Physical Address.*: ", ""

    foreach ($ip in $ips) {

        if ($ip.AddressFamily -eq "IPv4" -and $ip.IPAddress -ne "127.0.0.1") {
            # get the ipv4 info
            if ($AddressType -eq "IPv4" -or $AddressType -eq "both") {
                $mac = $macAddresses | Where-Object { $ip.InterfaceAlias -like "*$_*" } | Select-Object -First 1
                $ipAddresses += [PSCustomObject]@{
                    IPAddress   = $ip.IPAddress
                    Prefix      = $ip.PrefixLength
                    Interface   = $ip.InterfaceAlias
                    AddressType = "IPv4"
                    MACAddress  = $mac
                }
            }
        }

        elseif ($ip.AddressFamily -eq "IPv6" -and $ip.IPAddress -notlike "::1") {
            # get the ipv6 info
            if ($AddressType -eq "IPv6" -or $AddressType -eq "both") {
                $mac = $macAddresses | Where-Object { $ip.InterfaceAlias -like "*$_*" } | Select-Object -First 1
                $ipAddresses += [PSCustomObject]@{
                    IPAddress   = $ip.IPAddress
                    Prefix      = $ip.PrefixLength
                    Interface   = $ip.InterfaceAlias
                    AddressType = "IPv6"
                    MACAddress  = $mac
                }
            }
        }
    }

    return $ipAddresses
}


if ($MyInvocation.InvocationName -eq '.') {
    Write-Host "ip command initiated"
    
}
else {
    Get-IPAddress 

}