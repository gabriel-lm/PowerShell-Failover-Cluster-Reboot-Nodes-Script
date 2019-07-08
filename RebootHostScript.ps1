Import-Module FailoverClusters
$clusters = get-cluster -Domain domain.com | Where-Object {($_.Name -like 'node2*') -or ($_.Name -like 'node1*')}

$RebootCluster = {
    [CmdletBinding()]
    param ($clname)
    $nodes = Get-Cluster -name $clname | Get-ClusterNode
    for ($j=0; $j -lt $nodes.Count; $j++){
        Write-Host $nodes[$j]
        if ($nodes[$j].state -eq 'Up'){
            Write-Host $nodes[$j]
            $nodes[$j] | suspend-ClusterNode -Drain
            $vms = Get-VM -ComputerName $nodes[$j]
            do {Write-Host 'Draining roles..'
                Start-Sleep -Seconds 10
            } while ($vms.count -ne 0)
            if ($nodes[$j].state -eq 'Paused'){    
                Restart-Computer -ComputerName $nodes[$j] -Force}
            do {Write-Host 'Waiting for node to get back Online..'
                Start-Sleep -Seconds 30
            } while ($nodes[$j].state -eq 'Down')
            if ($nodes[$j].state -eq 'Paused'){
                $nodes[$j] | Resume-ClusterNode }
            Start-Sleep -Seconds 10
            if ($nodes[$j].state -eq 'Up'){
                Write-Host 'Node Up!'}
        }   
    }
}

For ($i=0; $i -lt $clusters.Count; $i++){
    $job = Start-Job -ScriptBlock $RebootCluster -ArgumentList $clusters[$i]
    $job | Format-List -Property *
}
