# 修复 try? 转换中被多余括号包裹的 try 表达式：
# "Ok(\n  EXPR,\n) catch" 或 "( EXPR ) catch" 形式 -> 去掉包裹括号
$ErrorActionPreference = 'Stop'

function Skip-Str([string]$s, [int]$i) {
  $i++
  while ($i -lt $s.Length) {
    $c = $s[$i]
    if ($c -eq '\') {
      if ($i + 1 -lt $s.Length -and $s[$i + 1] -eq '{') {
        $depth = 1
        $i += 2
        while ($i -lt $s.Length -and $depth -gt 0) {
          $d = $s[$i]
          if ($d -eq '"') { $i = Skip-Str $s $i; continue }
          if ($d -eq '\') { $i += 2; continue }
          if ($d -eq '{') { $depth++ } elseif ($d -eq '}') { $depth-- }
          $i++
        }
        continue
      }
      $i += 2
      continue
    }
    if ($c -eq '"') { return ($i + 1) }
    $i++
  }
  return $i
}

# 找到 s 中下标 openIdx 处 '(' 的匹配右括号位置；失败返回 -1
function Match-Paren([string]$s, [int]$openIdx) {
  $depth = 0
  $i = $openIdx
  while ($i -lt $s.Length) {
    $c = $s[$i]
    if ($c -eq '"') { $i = Skip-Str $s $i; continue }
    if ($c -eq '(' -or $c -eq '[' -or $c -eq '{') { $depth++ }
    elseif ($c -eq ')' -or $c -eq ']' -or $c -eq '}') {
      $depth--
      if ($depth -eq 0) { return $i }
    }
    $i++
  }
  return -1
}

$files = Get-ChildItem -Path . -Recurse -Include *.mbt, *.mbt.md |
  Where-Object { $_.FullName -notmatch '\\(\.mooncakes|_build|\.git)\\' }

$total = 0
foreach ($f in $files) {
  $content = [System.IO.File]::ReadAllText($f.FullName)
  if ($content -notmatch 'catch') { continue }
  $changed = 0
  # 反复处理直到不再变化（从前往后扫描）
  $searchFrom = 0
  while ($true) {
    $idx = $content.IndexOf(' catch', $searchFrom)
    if ($idx -lt 0) { break }
    # 向前找最近的非空白字符
    $k = $idx - 1
    while ($k -ge 0 -and ($content[$k] -eq ' ' -or $content[$k] -eq "`t" -or $content[$k] -eq "`n" -or $content[$k] -eq "`r")) { $k-- }
    if ($k -ge 0 -and $content[$k] -eq ')') {
      # 找匹配的左括号
      $depth = 0
      $j = $k
      $open = -1
      while ($j -ge 0) {
        $c = $content[$j]
        if ($c -eq ')' -or $c -eq ']' -or $c -eq '}') { $depth++ }
        elseif ($c -eq '(' -or $c -eq '[' -or $c -eq '{') {
          $depth--
          if ($depth -eq 0) { $open = $j; break }
        }
        $j--
      }
      if ($open -ge 0 -and $content[$open] -eq '(') {
        # 检查左括号前是否是函数/构造器名（标识符字符）
        $p = $open - 1
        while ($p -ge 0 -and ($content[$p] -eq ' ' -or $content[$p] -eq "`t" -or $content[$p] -eq "`n" -or $content[$p] -eq "`r")) { $p-- }
        $isCall = $false
        if ($p -ge 0 -and ($content[$p] -match '[A-Za-z0-9_)\].]')) { $isCall = $true }
        if (-not $isCall) {
          $inner = $content.Substring($open + 1, $k - $open - 1)
          # 去掉首行前导空白与末行尾随空白/逗号
          $trimmed = $inner.Trim()
          if ($trimmed.EndsWith(',')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1).TrimEnd() }
          if ($trimmed.Length -gt 0 -and $inner -ne $trimmed) {
            # 仅当内部确实含有换行（多行被包裹）才修复，避免误伤单行分组括号
            if ($inner -match "`n") {
              $content = $content.Substring(0, $open) + $trimmed + $content.Substring($k + 1)
              $changed++
              $searchFrom = $open + $trimmed.Length
              continue
            }
          }
        }
      }
    }
    $searchFrom = $idx + 6
  }
  if ($changed -gt 0) {
    [System.IO.File]::WriteAllText($f.FullName, $content)
    Write-Output ("repaired: " + $f.FullName + " (" + $changed + " sites)")
    $total += $changed
  }
}
Write-Output ("total repaired: " + $total)
