# 批量迁移 try? 弃用语法（第二阶段：括号匹配转换）
$ErrorActionPreference = 'Stop'

function Skip-String([string]$s, [int]$i) {
  # $s[$i] == '"'，返回字符串字面量结束后的下标
  $i++
  while ($i -lt $s.Length) {
    $c = $s[$i]
    if ($c -eq '\') {
      if ($i + 1 -lt $s.Length -and $s[$i + 1] -eq '{') {
        $depth = 1
        $i += 2
        while ($i -lt $s.Length -and $depth -gt 0) {
          $d = $s[$i]
          if ($d -eq '"') { $i = Skip-String $s $i; continue }
          if ($d -eq '\') { $i += 2; continue }
          if ($d -eq '{') { $depth++ }
          elseif ($d -eq '}') { $depth-- }
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

function Find-ExprEnd([string]$s, [int]$start, [bool]$matchMode) {
  $depth = 0
  $i = $start
  $len = $s.Length
  while ($i -lt $len) {
    $c = $s[$i]
    if ($c -eq '"') { $i = Skip-String $s $i; continue }
    if ($c -eq "'") {
      $j = $i + 1
      while ($j -lt $len -and $s[$j] -ne "'") {
        if ($s[$j] -eq '\') { $j++ }
        $j++
      }
      $i = $j + 1
      continue
    }
    if ($c -eq '/' -and $i + 1 -lt $len -and $s[$i + 1] -eq '/') {
      while ($i -lt $len -and $s[$i] -ne "`n") { $i++ }
      continue
    }
    if ($c -eq '(' -or $c -eq '[' -or $c -eq '{') {
      if ($c -eq '{' -and $depth -eq 0 -and $matchMode) { return $i }
      $depth++
      $i++
      continue
    }
    if ($c -eq ')' -or $c -eq ']' -or $c -eq '}') {
      if ($depth -eq 0) { return $i }
      $depth--
      $i++
      continue
    }
    if (($c -eq ',' -or $c -eq ';') -and $depth -eq 0) { return $i }
    if ($c -eq "`n" -and $depth -eq 0) {
      # 向前看最后一个非空白字符
      $k = $i - 1
      while ($k -ge $start -and ($s[$k] -eq ' ' -or $s[$k] -eq "`t")) { $k-- }
      $endsOp = $false
      if ($k -ge $start) {
        $lc = $s[$k]
        if ($k -ge $start + 1 -and $s.Substring($k - 1, 2) -eq '|>') { $endsOp = $true }
        elseif ($lc -in @('+', '-', '*', '/', '%', '=', '<', '>', '&', '|', '^', '.', ':', ',')) { $endsOp = $true }
      }
      # 向后看下一行首个非空白字符
      $m = $i + 1
      while ($m -lt $len -and ($s[$m] -eq ' ' -or $s[$m] -eq "`t")) { $m++ }
      $startsCont = $false
      if ($m -lt $len) {
        $nc = $s[$m]
        if ($nc -eq '.' -or $nc -eq '|') { $startsCont = $true }
        elseif ($m + 1 -lt $len -and $s.Substring($m, 2) -eq '|>') { $startsCont = $true }
      }
      if ($endsOp -or $startsCont) { $i++; continue }
      return $i
    }
    $i++
  }
  return $i
}

function Convert-TryQ([string]$content) {
  $changed = 0
  $positions = @()
  $idx = 0
  while (($idx = $content.IndexOf('try?', $idx)) -ge 0) {
    $positions += $idx
    $idx += 4
  }
  # 从后向前处理，保持下标有效
  for ($p = $positions.Count - 1; $p -ge 0; $p--) {
    $pos = $positions[$p]
    # 行首前缀
    $lineStart = $content.LastIndexOf("`n", $pos) + 1
    $prefix = $content.Substring($lineStart, $pos - $lineStart)
    if ($prefix -match '///') { continue } # 注释中不处理
    # 表达式起始位置（跳过空白）
    $e = $pos + 4
    while ($e -lt $content.Length -and ($content[$e] -eq ' ' -or $content[$e] -eq "`t")) { $e++ }
    $matchMode = ($prefix.TrimEnd() -match 'match$')
    $end = Find-ExprEnd $content $e $matchMode
    $expr = $content.Substring($e, $end - $e).TrimEnd()
    # 上下文检测
    $beforeTrim = $prefix.TrimEnd()
    if ($beforeTrim -match 'ignore\($') {
      $igStart = $lineStart + $prefix.Length - ($prefix.Length - $prefix.TrimEnd().Length) - 0
      # 定位 ignore( 起点
      $igStart = $content.LastIndexOf('ignore(', $pos)
      $closeParen = $end
      while ($closeParen -lt $content.Length -and ($content[$closeParen] -eq ' ' -or $content[$closeParen] -eq "`t" -or $content[$closeParen] -eq "`n")) { $closeParen++ }
      if ($closeParen -lt $content.Length -and $content[$closeParen] -eq ')') {
        $repl = 'try ' + $expr + ' catch { _ => () }'
        $content = $content.Substring(0, $igStart) + $repl + $content.Substring($closeParen + 1)
        $changed++
        continue
      }
    }
    if ($prefix.Trim() -eq '') {
      # 语句级：吞掉错误
      $repl = 'try ' + $expr + ' catch { _ => () }'
    } else {
      $repl = 'try Ok(' + $expr + ') catch { e => Err(e) }'
    }
    $content = $content.Substring(0, $pos) + $repl + $content.Substring($end)
    $changed++
  }
  return @($content, $changed)
}

$files = Get-ChildItem -Path . -Recurse -Include *.mbt, *.mbt.md |
  Where-Object { $_.FullName -notmatch '\\(\.mooncakes|_build|\.git)\\' }

$total = 0
foreach ($f in $files) {
  $content = [System.IO.File]::ReadAllText($f.FullName)
  if ($content -notmatch 'try\?') { continue }
  $res = Convert-TryQ $content
  if ($res[1] -gt 0) {
    [System.IO.File]::WriteAllText($f.FullName, $res[0])
    Write-Output ("modified: " + $f.FullName + " (" + $res[1] + " sites)")
    $total += $res[1]
  }
}
Write-Output ("total try? migrated: " + $total)
