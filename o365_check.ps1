$dir = Get-ChildItem $PSScriptRoot\*.csv
function menu {
    $i = 1
    Clear-Host
    Write-Host "Select CSV:"
    Write-Host ""
    ForEach($csv in $dir){
        Write-Host $i ": $csv"
        $i++
    }
    $selection = Read-Host
    Return $selection - 1
}
# Start menu and get selection - no exception handling
$x = menu

# Define import CSV path based on selection
$path = $dir[$x].FullName

# Load customers into array
$allCustomers = Import-Csv "$path" | ForEach-Object {
    $_.Website = $_.Website -replace "^(https?:\/\/(www.)?)|www.|(?<=\w)\/.*",''
    $_
}

# Counter
$total = $allCustomers.Count
$count = 0

# Define output array
$output = @()

# Define output file name
$outputPath = $path -replace '.csv','_output.csv'

ForEach($customer in $allCustomers){


    $txt = Resolve-DnsName -Type TXT -Name $customer.Website
    $mx = Resolve-DnsName -Type MX -Name $customer.Website
    
    # See: https://docs.microsoft.com/en-us/microsoft-365/admin/get-help-with-domains/create-dns-records-at-any-dns-hosting-provider?view=o365-worldwide
    # 1: Checks for protection.outlook.com SPF record
    # 2: Checks for TXT record with unique ID verifying domain ownership for O365
    # 3: Checks for outlook.com MX record
    #
    # 1
    if($txt.Strings -like "*spf.protection.outlook.com*")
    { $customer | Add-Member -MemberType NoteProperty -Name SPF -Value $True } else { $customer | Add-Member -MemberType NoteProperty -Name SPF -Value $False }

    # 2
    if($txt.Strings -like "*MS=ms*")
    { $customer | Add-Member -MemberType NoteProperty -Name UID -Value $True } else { $customer | Add-Member -MemberType NoteProperty -Name UID -Value $False }

    # 3
    if($mx.NameExchange -like "*outlook.com*")
    { $customer | Add-Member -MemberType NoteProperty -Name MX -Value $True } else { $customer | Add-Member -MemberType NoteProperty -Name MX -Value $False }

    if(($customer.SPF -eq $True) -or ($customer.UID -eq $True) -or ($customer.MX -eq $True)){
    $output += $customer
    }

    
$count++
Write-Progress -Activity "Checking DNS record for $customer.Website" -PercentComplete (($count/$total)*100)
}
$output | Export-csv $outputPath -NoTypeInformation
