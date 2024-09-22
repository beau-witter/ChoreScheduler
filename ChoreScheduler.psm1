function Get-ChoreTasks {
    [CmdletBinding()]
    param ()
    
    Get-Content "$HOME\ChoreScheduler_tasks.json" | ConvertFrom-Json
}

function Set-ChoreTasks {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][PSCustomObject[]] $ChoreTasks
    )

    $ChoreTasks | ConvertTo-Json -Depth 10 | Set-Content "$HOME\ChoreScheduler_tasks.json"
}

function Update-ChoreTaskDates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][PSCustomObject[]] $ChoreTasks,
        [Parameter()][DateTime] $CompareDate = (Get-Date)
    )

    $ChoreTasks.Locations | ForEach-Object {
        if($_.Frequency.ToLower() -ne "daily")
        {
            if($null -eq $_.Every)
            {
                $_ | Add-Member -MemberType NoteProperty -Name "Every" -Value 1
            }
                
            if($null -eq $_.StartDate)
            {
                $_ | Add-Member -MemberType NoteProperty -Name "StartDate" -Value (Get-StartDate -CompareDate $CompareDate -Chore $_)
            }
            
            $nextDate = Get-NextDate -CompareDate $CompareDate -Chore $_
            if($null -eq $_.NextDate)
            {
                $_ | Add-Member -MemberType NoteProperty -Name "NextDate" -Value $nextDate
            }
            else
            {
                $_.NextDate = $nextDate
            }
        }
    }
}

function Get-StartDate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][DateTime] $CompareDate,
        [Parameter(Mandatory = $true)][PSCustomObject] $Chore
    )

    if($Chore.Frequency.ToLower() -eq "weekly")
    {
        $possibleNext = $CompareDate.Date.AddDays([int][dayofweek]::($Chore.Occurrence) - $CompareDate.DayOfWeek)
        if($CompareDate -gt $possibleNext)
        {
            $possibleNext.Date.AddDays(7)
        }
        else {
            $possibleNext
        }
    }
    else #($Chore.Frequency.ToLower() -eq "monthly" -or $Chore.Frequency.ToLower() -eq "quarterly" -or $Chore.Frequency.ToLower() -eq "yearly")
    {
        if($CompareDate.Day -gt $Chore.Occurrence)
        {
            $CompareDate.Date.AddDays(-$CompareDate.Day + 1).AddMonths(1).AddDays($Chore.Occurrence - 1)
        }
        else
        {
            $CompareDate.Date.AddDays($Chore.Occurrence - $CompareDate.Date.Day)
        }
    }
}

function Get-NextDate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][DateTime] $CompareDate,
        [Parameter(Mandatory = $true)][PSCustomObject] $Chore
    )

    if($null -eq $Chore.NextDate)
    {
        $Chore.StartDate
    }
    elseif($Chore.NextDate -gt $CompareDate)
    {
        $Chore.NextDate
    }
    else
    {
        if($Chore.Frequency.ToLower() -eq "daily")
        {
            $Chore.NextDate.AddDays(1)
        }
        elseif($Chore.Frequency.ToLower() -eq "weekly")
        {
            $Chore.NextDate.AddDays($Chore.Every * 7)
        }
        elseif($Chore.Frequency.ToLower() -eq "monthly")
        {
            $Chore.NextDate.AddMonths($Chore.Every)
        }
        elseif($Chore.Frequency.ToLower() -eq "quarterly") {
            $Chore.NextDate.AddMonths(3)
        }
        elseif($Chore.Frequency.ToLower() -eq "yearly")
        {
            $Chore.NextDate.AddYears($Chore.Every)
        }
        else
        {
            $null
        }
    }
}

function Get-ChoreTasksForWeek {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][PSCustomObject[]] $ChoreTasks,
        [Parameter()][DateTime] $CompareDate = (Get-Date)
    )
    
    $ChoreTasks | ForEach-Object {
        [PSCustomObject]@{
            "ChoreName" = $_.ChoreName
            "Locations" = $_.Locations | Where-Object {
                $_.NextDate -le $CompareDate.Date.AddDays(7) -or
                $_.Frequency.ToLower() -eq "daily"
            }
        }
    }
}

function Format-ResultsForCSV {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][PSCustomObject[]] $ChoreTasks,
        [Parameter(Mandatory = $true)][DateTime] $CompareDate,
        [Parameter()][switch] $Daily
    )
    
    $weekChores = 1..100 | ForEach-Object {
        [PSCustomObject]@{
            "Sunday - $((Get-Culture).DateTimeFormat.GetMonthName($CompareDate.Month) + " " + $CompareDate.Day)" = $null
            "Monday - $((Get-Culture).DateTimeFormat.GetMonthName(($CompareDate.AddDays(1)).Month) + " " + $CompareDate.AddDays(1).Day)" = $null
            "Tuesday - $((Get-Culture).DateTimeFormat.GetMonthName(($CompareDate.AddDays(2)).Month) + " " + $CompareDate.AddDays(2).Day)" = $null
            "Wednesday - $((Get-Culture).DateTimeFormat.GetMonthName(($CompareDate.AddDays(3)).Month) + " " + $CompareDate.AddDays(3).Day)" = $null
            "Thursday - $((Get-Culture).DateTimeFormat.GetMonthName(($CompareDate.AddDays(4)).Month) + " " + $CompareDate.AddDays(4).Day)" = $null
            "Friday - $((Get-Culture).DateTimeFormat.GetMonthName(($CompareDate.AddDays(5)).Month) + " " + $CompareDate.AddDays(5).Day)" = $null
            "Saturday - $((Get-Culture).DateTimeFormat.GetMonthName(($CompareDate.AddDays(6)).Month) + " " + $CompareDate.AddDays(6).Day)" = $null
        }
    }

    if(-not $Daily.IsPresent)
    {
        $flatChores = $ChoreTasks | Where-Object { $_.Locations } | Select-Object ChoreName -ExpandProperty Locations | Where-Object { $_.Frequency.ToLower() -ne "daily" } | Sort-Object -Property LocationName,ChoreName

        # Sunday
        $i = 0
        $flatChores | Where-Object { $_.NextDate.DayOfWeek -eq "Sunday" } | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Sunday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }

        # Monday
        $i = 0
        $flatChores | Where-Object { $_.NextDate.DayOfWeek -eq "Monday" } | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Monday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }

        # Tuesday
        $i = 0
        $flatChores | Where-Object { $_.NextDate.DayOfWeek -eq "Tuesday" } | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Tuesday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }

        # Wednesday
        $i = 0
        $flatChores | Where-Object { $_.NextDate.DayOfWeek -eq "Wednesday" } | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Wednesday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }

        # Thursday
        $i = 0
        $flatChores | Where-Object { $_.NextDate.DayOfWeek -eq "Thursday" } | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Thursday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }

        # Friday
        $i = 0
        $flatChores | Where-Object { $_.NextDate.DayOfWeek -eq "Friday" } | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Friday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }

        # Saturday
        $i = 0
        $flatChores | Where-Object { $_.NextDate.DayOfWeek -eq "Saturday" } | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Saturday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }
    }
    else
    {
        
        $flatChores = $ChoreTasks | Where-Object { $_.Locations } | Select-Object ChoreName -ExpandProperty Locations | Where-Object { $_.Frequency.ToLower() -eq "daily" } | Sort-Object -Property LocationName,ChoreName

        $i = 0
        $flatChores | ForEach-Object {
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Sunday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Monday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Tuesday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Wednesday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Thursday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Friday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $weekChores[$i].($weekChores[$i] | Get-Member | Where-Object { $_.Name -like "Saturday*" } | Select-Object -ExpandProperty Name) = $_.LocationName + " - " + $_.ChoreName
            $i++
        }
    }

    $weekChores
}

function Get-SundayBasedDate {
    param (
        [Parameter()][AllowNull()][System.Nullable[DateTime]] $CompareDate
    )
    
    if($null -eq $CompareDate)
    {
        $now = (Get-Date).Date
        if($now.DayOfWeek -eq "Sunday")
        {
            $CompareDate = $now
        }
        else
        {
            $CompareDate = $now.AddDays(-[int]$now.DayOfWeek)
        }
    }
    else
    {
        $CompareDate = $CompareDate.Date
        if($CompareDate.DayOfWeek -ne "Sunday")
        {
            $CompareDate = $CompareDate.AddDays(-[int]$CompareDate.DayOfWeek)
        }
    }

    $CompareDate
}

function New-ChoreOutput {
    [CmdletBinding()]
    param (
        [Parameter()][DateTime] $CompareDate
    )

    $CompareDate = Get-SundayBasedDate -CompareDate $CompareDate

    $choreTasks = Get-ChoreTasks
    Update-ChoreTaskDates -ChoreTasks $choreTasks -CompareDate $CompareDate
    Set-ChoreTasks -ChoreTasks $choreTasks

    Get-ChoreTasksForWeek -ChoreTasks $choreTasks -CompareDate $CompareDate
}