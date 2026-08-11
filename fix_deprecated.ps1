# 批量修复弃用 API 调用（第一阶段：机械替换）
$ErrorActionPreference = 'Stop'
$files = Get-ChildItem -Path . -Recurse -Include *.mbt, *.mbt.md |
  Where-Object { $_.FullName -notmatch '\\(\.mooncakes|_build|\.git)\\' }

$rules = @(
  @{ Pattern = 'Ref::new\('; Replace = 'Ref(' },
  @{ Pattern = 'Queue::new\('; Replace = 'Queue(' },
  @{ Pattern = 'Server::new\('; Replace = 'Server(' },
  @{ Pattern = 'Client::new\('; Replace = 'Client(' },
  @{ Pattern = 'Semaphore::new\('; Replace = 'Semaphore(' },
  @{ Pattern = 'Map::new\(\)'; Replace = 'Map([])' },
  @{ Pattern = '@buffer\.new\(\)'; Replace = 'Buffer()' }
)

$total = 0
foreach ($f in $files) {
  $content = [System.IO.File]::ReadAllText($f.FullName)
  $orig = $content
  foreach ($r in $rules) {
    $content = [regex]::Replace($content, $r.Pattern, $r.Replace)
  }
  if ($content -ne $orig) {
    [System.IO.File]::WriteAllText($f.FullName, $content)
    $diff = 1
    Write-Output ("modified: " + $f.FullName)
    $total++
  }
}
Write-Output ("total files modified: " + $total)
