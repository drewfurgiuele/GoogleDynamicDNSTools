#Load each function
foreach ($function in (Get-ChildItem "$PSScriptRoot\functions\*.ps1")) { . $function }