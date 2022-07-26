$phone = @(
""
)
$property = @(
    ""

)

Connect-MgGraph -Scopes UserAuthenticationMethod.ReadWrite.All
Select-MgProfile -Name beta


for($i = 0; $i -lt $phone.Count; $i++){
    $prop = $property[$i] + "@domain"
    $auth = $phone[$i]
    Remove-MgUserAuthenticationPhoneMethod -UserId $prop -PhoneAuthenticationMethodId "ID"
    Write-Warning "Setting $prop Authentication Phone: $auth"
    New-MgUserAuthenticationPhoneMethod -UserId $prop -phoneType "mobile" -phoneNumber $auth
}
