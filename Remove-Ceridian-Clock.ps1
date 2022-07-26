$users = Get-ChildItem -Path "C:\Users"

foreach($u in $users){
    $desktop = "C:\Users\"+$u.Name+"\Desktop"

    Get-ChildItem -Path $desktop -Recurse -ErrorAction SilentlyContinue | Where-Object{$_.Name -Match "^(.*?)[Cc]lock.exe"} | Remove-Item 
    Get-ChildItem -Path $desktop -Recurse -ErrorAction SilentlyContinue | Where-Object{$_.Name -Match "^(.*?)[Cc]lock.lnk"} | Remove-Item 
    Get-ChildItem -Path $desktop -Recurse -ErrorAction SilentlyContinue | Where-Object{$_.Name -Match "^(.*?)[Cc]lock.url"} | Remove-Item 
}
