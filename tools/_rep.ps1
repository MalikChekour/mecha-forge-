param([string]$f,[string]$old,[string]$new)
$t=[IO.File]::ReadAllText($f)
$n=([regex]::Matches($t,[regex]::Escape($old))).Count
if($n -ne 1){ Write-Output "FAIL $f count=$n"; exit 1 }
$t=$t.Replace($old,$new)
[IO.File]::WriteAllText($f,$t,(New-Object Text.UTF8Encoding($false)))
Write-Output "OK $f"