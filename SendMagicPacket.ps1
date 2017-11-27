########################################################
# マジックパケット送信
########################################################
param(
	$NetworkAddress,	# Network Address(CIDR)
	$MacAddress			# Terget MAC Address( "-" or ":" or space)
	)

$C_MacAddressSize = 6
$C_MagicPacketSize = 102

########################################################
# MAC アドレス文字列を byte データにする
########################################################
function ConvertMacAddressString2ByteData( [string] $MacAddressString ){
	if( $MacAddressString.Contains("-") ){
		$MacDatas = $MacAddressString.Split("-")
	}
	elseif( $MacAddressString.Contains(":") ){
		$MacDatas = $MacAddressString.Split(":")
	}
	elseif( $MacAddressString.Contains(" ") ){
		$MacDatas = $MacAddressString.Split(" ")
	}
	else{
		return $null
	}

	if( $MacDatas.Count -ne $C_MacAddressSize ){
		return $null
	}

	$ReturnData = New-Object byte[] $C_MacAddressSize

	for( $i=0; $i -lt $C_MacAddressSize; $i++){
		$ReturnData[$i] = [System.Convert]::ToByte($MacDatas[$i], 16)
	}

	return $ReturnData
}

########################################################
# マジックパケットデータを作成する
########################################################
function CreateMagicPacketData( $MacAddressByte ){
	$ReturnData = New-Object byte[] 102

	# 先頭の 6 バイトの 0xff
	for($i=0; $i -lt $C_MacAddressSize; $i++){
		$ReturnData[$i] = 0xff
	}

	# MAC アドレスを 16 個セット
	for(; $i -lt $C_MagicPacketSize; $i++){
		$ReturnData[$i] = $MacAddressByte[$i % $C_MacAddressSize]
	}

	return $ReturnData
}


########################################################
# ブロードキャストアドレスを得る
########################################################
function CalcBroadcastAddressv4( $IP, $Subnet ){

	# CIDR の時は サブネットマスクに変換する
	if( $Subnet -eq $null ){
		$Temp = $IP -split "/"
		$IP = $Temp[0]
		$CIDR = $Temp[1]
		$intCIDR = [int]$Temp[1]
		for( $i = 0 ; $i -lt 4 ; $i++ ){
			# all 1
			if( $intCIDR -ge 8 ){
				$Subnet += "255"
				$intCIDR -= 8
			}
			# all 0
			elseif($intCIDR -le 0){
				$Subnet += "0"
				$intCIDR = 0
			}
			else{
				# オクテット内 CIDR で表現できる最大数
				$intNumberOfNodes = [Math]::Pow(2,8 - $intCIDR)
				# サブネットマスクを求める
				$intSubnetOct = 256 - $intNumberOfNodes
				$Subnet += [string]$intSubnetOct
				$intCIDR = 0
			}

			# ラストオクテットにはピリオドを付けない
			if( $i -ne 3 ){
				$Subnet += "."
			}
		}
	}
	# サブネットマスクの時は CIDR を求める
	else{
		$SubnetOct = $Subnet -split "\."
		$intCIDR = 0
		for( $i = 0 ; $i -lt 4 ; $i++ ){
			# オクテット内のビットマスクを作る
			$intSubnetOct = $SubnetOct[$i]
			$strBitMask = [Convert]::ToString($intSubnetOct,2)

			# マスクのビット長カウント
			for( $j = 0 ; $j -lt 8; $j++ ){
				if( $strBitMask[$j] -eq "1" ){
					$intCIDR++
				}
			}
		}
		$CIDR = [string]$intCIDR
	}

	$SubnetOct = $Subnet -split "\."
	$IPOct = $IP -split "\."

	# ネットワーク ID の算出
	$StrNetworkID = ""
	for( $i = 0 ; $i -lt 4 ; $i++ ){
		$intSubnetOct = [int]$SubnetOct[$i]
		$intIPOct = [int]$IPOct[$i]
		$intNetworkID = $intIPOct -band $intSubnetOct

		$StrNetworkID += [string]$intNetworkID

		if( $i -ne 3 ){
			$StrNetworkID += "."
		}
	}

	# ブロードキャストアドレスの算出
	$NetworkIDOct = $StrNetworkID  -split "\."
	for( $i = 0 ; $i -lt 4 ; $i++ ){
		$intSubnetOct = [int]$SubnetOct[$i]
		$intNetworkIDOct = [int]$NetworkIDOct[$i]
		$BitPattern = $intSubnetOct -bxor 255
		$intBroadcastAddress = $intNetworkIDOct -bxor $BitPattern
		$StrBroadcastAddress += [string]$intBroadcastAddress

		if( $i -ne 3 ){
			$StrBroadcastAddress += "."
		}
	}
	return $StrBroadcastAddress
}

########################################################
# UDP パケットを送信する
########################################################
function SendPacket( $BroadcastAddress, $ByteData, $Port ){

	# アセンブリがロード
	Add-Type -AssemblyName System.Net

	# UDP ソケット作る
	$UDPSocket = New-Object System.Net.Sockets.UdpClient($BroadcastAddress, $Port)

	if( $UDPSocket -ne $null ){
		# 送信
		[void]$UDPSocket.Send($ByteData, $ByteData.Length)

		# ソケット Close
		$UDPSocket.Close()
	}
}

########################################################
# main
########################################################
if( $NetworkAddress -eq $null ){
	echo "Usage..."
	echo "    SendMagicPacket.ps1 NetworkAddress(CIDR) TergetMacAddress( "-" or ":" or space)"
	exit
}

# MAC アドレス文字列を byte データにする
$MacAddressByte = ConvertMacAddressString2ByteData $MacAddress
if( $MacAddressByte -eq $null ){
	echo "[FAIL] Bad MAC Address format"
	exit
}

# マジックパケットデータを作成する
$ByteData = CreateMagicPacketData $MacAddressByte

# ブロードキャストアドレスを得る
$BroadcastAddress = CalcBroadcastAddressv4 $NetworkAddress

# マジックパケットを送信する
SendPacket $BroadcastAddress $ByteData 7

