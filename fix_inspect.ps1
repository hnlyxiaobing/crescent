# 第三阶段：按警告位置将 Show 版 inspect 迁移为 Debug 版 debug_inspect
$ErrorActionPreference = 'Stop'

# 从 warnings.txt 读取 (文件, 行号)，仅处理 Show/Debug 类警告
$targets = @{}
foreach ($line in Get-Content warnings.txt) {
  if ($line -match '^(D:[^:]+):(\d+):\d+ \| deprecated \| (Use Debug|`Show`)') {
    $file = $Matches[1]
    $ln = [int]$Matches[2]
    if (-not $targets.ContainsKey($file)) { $targets[$file] = @() }
    $targets[$file] += $ln
  }
}

$total = 0
foreach ($file in $targets.Keys) {
  $lines = [System.IO.File]::ReadAllLines($file)
  $changed = 0
  foreach ($ln in ($targets[$file] | Sort-Object)) {
    $idx = $ln - 1
    # 含字符串插值的行（fail 消息等）不由本脚本处理，稍后手动迁移
    if ($lines[$idx] -match '\\\{') {
      Write-Output ("INTERP-SKIP: " + $file + ":" + $ln)
      continue
    }
    # 向上查找最近的未迁移 inspect( 调用（最多回溯 6 行）
    $found = -1
    for ($j = $idx; $j -ge [Math]::Max(0, $idx - 6); $j--) {
      if ($lines[$j] -match '(?<!debug_)inspect\(') { $found = $j; break }
    }
    if ($found -ge 0) {
      $lines[$found] = [regex]::Replace($lines[$found], '(?<!debug_)inspect\(', 'debug_inspect(', 1)
      $changed++
    } else {
      Write-Output ("UNHANDLED: " + $file + ":" + $ln)
    }
  }
  if ($changed -gt 0) {
    [System.IO.File]::WriteAllLines($file, $lines)
    Write-Output ("modified: " + $file + " (" + $changed + " inspects)")
    $total += $changed
  }
}
Write-Output ("total inspects migrated: " + $total)
