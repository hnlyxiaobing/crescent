# 解析 moon check 日志，输出 文件:行:列 -> 警告消息 清单
$lines = Get-Content check_output.log -Encoding UTF8
$curLoc = $null
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '\[ (D:[^\]]+) \]') {
    $curLoc = $Matches[1]
  }
  if ($lines[$i] -match 'Warning \(([^)]+)\): (.*)$') {
    $kind = $Matches[1]
    $msg = $Matches[2]
    if ($msg.Length -gt 70) { $msg = $msg.Substring(0, 70) }
    Write-Output ("$curLoc | $kind | $msg")
  }
}
