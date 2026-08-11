# 迭代修复：inspect→debug_inspect + 插值 Repr 包裹，直到无此类警告
$ErrorActionPreference = 'Stop'
$maxIter = 8

for ($iter = 1; $iter -le $maxIter; $iter++) {
  Write-Output ("===== iteration " + $iter + " =====")
  # 1. 处理 inspect 类
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\fix_inspect.ps1

  # 2. 处理插值类：按警告行包裹 Repr
  $interpFixed = 0
  $byFile = @{}
  foreach ($line in Get-Content warnings.txt) {
    if ($line -match '^(D:[^:]+):(\d+):\d+ \| deprecated \| (Use Debug|`Show`)') {
      $f = $Matches[1]
      if (-not $byFile.ContainsKey($f)) { $byFile[$f] = @() }
      $byFile[$f] += [int]$Matches[2]
    }
  }
  foreach ($f in $byFile.Keys) {
    $lines = [System.IO.File]::ReadAllLines($f)
    $changed = $false
    foreach ($ln in ($byFile[$f] | Sort-Object -Unique)) {
      $i = $ln - 1
      if ($lines[$i] -match '\\\{') {
        $new = $lines[$i] -replace '\\\{(code|reason|result|expected_code|expected_reason)\}', '\{Repr($1)}'
        if ($new -ne $lines[$i]) {
          $lines[$i] = $new
          $changed = $true
          $interpFixed++
        }
      }
    }
    if ($changed) { [System.IO.File]::WriteAllLines($f, $lines) }
  }
  Write-Output ("interp fixes: " + $interpFixed)

  # 3. 重新检查（用 cmd 重定向避免 stderr 触发 NativeCommandError）
  cmd /c "moon check > check_output.log 2>&1"
  $fin = Select-String -Path check_output.log -Pattern 'Finished|Failed' | Select-Object -Last 1
  Write-Output $fin.Line
  & powershell -NoProfile -ExecutionPolicy Bypass -File .\parse_warn.ps1 > warnings.txt
  $count = @(Get-Content warnings.txt | Where-Object { $_ -match '^D:' }).Count
  Write-Output ("remaining warnings: " + $count)
  if ($count -eq 0) { break }
}
