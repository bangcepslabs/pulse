$ErrorActionPreference = 'Stop'

$androidDir = $PSScriptRoot
$keyPath = Join-Path $androidDir 'app\pulse-upload-key.jks'
$propertiesPath = Join-Path $androidDir 'key.properties'

if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw 'Upload key files already exist. Back them up instead of generating replacements.'
}

$keytool = Get-Command keytool -ErrorAction Stop
$passwordBytes = New-Object byte[] 32
$random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$random.GetBytes($passwordBytes)
$random.Dispose()
$password = [Convert]::ToBase64String($passwordBytes)

& $keytool.Source `
    -genkeypair `
    -v `
    -keystore $keyPath `
    -storepass $password `
    -keypass $password `
    -alias 'pulse-upload' `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -dname 'CN=Pulse Lab, OU=Mobile, O=Pulse Lab, L=Seoul, ST=Seoul, C=KR'

if ($LASTEXITCODE -ne 0) {
    throw "keytool failed with exit code $LASTEXITCODE"
}

$properties = @(
    "storePassword=$password"
    "keyPassword=$password"
    'keyAlias=pulse-upload'
    'storeFile=pulse-upload-key.jks'
)
[System.IO.File]::WriteAllLines($propertiesPath, $properties)

Write-Host "Created upload key: $keyPath"
Write-Host "Created signing config: $propertiesPath"
Write-Host 'Back up both files securely. Losing the upload key can block future updates.'
