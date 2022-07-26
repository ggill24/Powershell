$cred = Get-Credential
#$computers = Get-ADComputer -Filter * -SearchBase "" -Credential $cred | Select-Object -ExpandProperty "Name"
$computers = 'COMPUTERS'
$servers = @{}
$servers.Add('SERVER','PORTS')


foreach ($c in $computers) {
    
    try {
        
        $session = Enter-PSSession -ComputerName $c -Credential -$cred
        $test = Invoke-Command -Session $session -ScriptBlock{
            $results = @()
            foreach($s in $using:servers){
                $ports = @($s.Values.Split(','))
                foreach ($p in $ports) {
                    $testResult = Test-NetConnection -ComputerName $s.Keys -Port $p | Select-Object -ExpandProperty TcpTestSucceeded
                    $results.Add($s.Keys + ',' + $p + ',' + $testResult)
                }
                

            }
           
        }
        Exit-PSSession $session
        $test
    }
    catch {
        Write-Host "PSSession failed for: $c"
        continue
    }
    
    break
}
