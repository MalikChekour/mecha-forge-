param([string]$tag = "ak", [string]$runs = "1:11", [string]$extra = "")
$G = "C:\Users\Administrator\tools\godot\Godot_v4.3-stable_win64_console.exe"
Set-Location C:\Users\Administrator\mecha-forge
foreach ($r in $runs.Split(",")) {
  $d, $s = $r.Split(":")
  $log = "qa_antikite\${tag}_d${d}_s${s}.log"
  Start-Process -FilePath $G -ArgumentList "--headless --path game res://_bal_ch1.tscn -- --ch=1 --diff=$d --secs=960 --scale=6 --seed=$s --no-protocols $extra" -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Hidden
}
