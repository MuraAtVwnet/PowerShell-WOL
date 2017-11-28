########################################################
# マジックパケット送信
########################################################
param(
	[array]$MacAddress,	# マジックパケットの送り先( - or : or space セパレート)
	$NetworkAddress,	# ネットワークアドレス(CIDR形式)
	$SubnetMask,		# サブネットマスク
	$Port = 7,			# UDP のポート番号
	[switch]$NoLog		# ログ出力
	)

# 定数
$C_MacAddressSize = 6
$C_MagicPacketSize = 102

# ログの出力先
$LogPath = Split-Path $MyInvocation.MyCommand.Path -Parent
# ログファイル名
$LogName = "PowerSehll_WOL"
#########################################################################
# ログ出力
##########################################################################
function Log(
			$LogString
			){


	$Now = Get-Date

	# Log 出力文字列に時刻を付加(YYYY/MM/DD HH:MM:SS.MMM $LogString)
	$Log = $Now.ToString("yyyy/MM/dd HH:mm:ss.fff") + " "
	$Log += $LogString

	# ログファイル名が設定されていなかったらデフォルトのログファイル名をつける
	if( $LogName -eq $null ){
		$LogName = "LOG"
	}

	# ログファイル名(XXXX_YYYY-MM-DD.log)
	$LogFile = $LogName + "_" +$Now.ToString("yyyy-MM-dd") + ".log"

	# ログフォルダーがなかったら作成
	if( -not (Test-Path $LogPath) ) {
		New-Item $LogPath -Type Directory
	}

	# ログファイル名
	$LogFileName = Join-Path $LogPath $LogFile

	# ログ出力
	Write-Output $Log | Out-File -FilePath $LogFileName -Encoding Default -append

	# echo させるために出力したログを戻す
	Return $Log
}
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
		try{
			$ReturnData[$i] = [System.Convert]::ToByte($MacDatas[$i], 16)
		}
		catch{
			return $null
		}
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

	try{
		# UDP ソケット作る
		$UDPSocket = New-Object System.Net.Sockets.UdpClient($BroadcastAddress, $Port)

		if( $UDPSocket -eq $null ){
			return $false
		}

		# 送信
		[void]$UDPSocket.Send($ByteData, $ByteData.Length)

		# ソケット Close
		$UDPSocket.Close()
	}
	catch{
		return $false
	}

	return $true
}

########################################################
# Usage
########################################################
function Usage(){
	echo ""
	echo "Usage..."
	echo "    WOL.ps1 -MacAddress Terget Mac Address -NetworkAddress Terget Network Address(s)"
	echo ""
	echo "    Options:"
	echo "        -MacAddress"
	echo "            Terget MAC Address(s) ( `"-`" or `":`" )"
	echo ""
	echo "        -NetworkAddress"
	echo "            Terget Network/CIDR"
	echo ""
	echo "        -SubnetMask"
	echo "            Subnet Mask"
	echo ""
	echo "        -Port"
	echo "            Terget UDP port number(default 7)"
	echo ""
	echo "        -NoLog"
	echo "            Log not output"
	echo ""
	echo "    e.g."
	echo "        WOL.ps1 02-15-90-CA-0F-2A 192.168.0.15/24"
	echo "        WOL.ps1 02-15-90-CA-0F-2A 192.168.0.15 255.255.255.0"
	echo "        WOL.ps1 -NetworkAddress 192.168.0.15/24 -MacAddress 02-15-90-CA-0F-2A -NoLog"
	echo ""
	echo '        $MacAddresses = "02-15-90-CA-0F-2A", "02-15-90-CA-0F-2B"'
	echo '        WOL.ps1 $MacAddresses 192.168.0.15/24'
	echo ""
}


########################################################
# main
########################################################
if( ($NetworkAddress -eq $null) -or ($MacAddress -eq $null) ){
	Usage
	exit
}

if( -not $NoLog ){
	# ログ表示抑制しつつログ記録
	$Dummy = Log "[INFO] ========= Start ========="
}

# ブロードキャストアドレスを得る
$BroadcastAddress = CalcBroadcastAddressv4 $NetworkAddress $SubnetMask

foreach($TergetMacAddress in $MacAddress){

	# MAC アドレス文字列を byte データにする
	$MacAddressByte = ConvertMacAddressString2ByteData $TergetMacAddress
	if( $MacAddressByte -eq $null ){
		$Message = "[FAIL] Bad MAC Address. $TergetMacAddress"
		if( -not $NoLog ){
			Log $Message
		}
		else{
			echo $Message
		}
		exit
	}

	# マジックパケットデータを作成する
	$ByteData = CreateMagicPacketData $MacAddressByte

	# マジックパケットを送信する
	[array]$Result = SendPacket $BroadcastAddress $ByteData $Port
	$Status = $Result[$Result.count -1]
	if( $Status -eq $false ){
		$Message = "[FAIL] WOL packet send fail."
		if( -not $NoLog ){
			Log $Message
		}
		else{
			echo $Message
		}
		exit
	}

	if( -not $NoLog ){
		Log "[INFO] Sended Magic Packet."
		Log "[INFO]     Broadcast Address  : $BroadcastAddress"
		Log "[INFO]     UDP port number    : $Port"
		Log "[INFO]     Terget MAC Address : $TergetMacAddress"
	}
}

if( -not $NoLog ){
	# ログ表示抑制しつつログ記録
	$Dummy = Log "[INFO] ========== End =========="
}

