$ModuleName = "New-CircularIcon"
New-ModuleManifest -Path ".\$($ModuleName)\$($ModuleName).psd1" `
    -RootModule      "$($ModuleName).psm1" `
    -ModuleVersion   '3.3.3' `
    -Author          'Connor Ross (@CyberCondor)' `
    -CompanyName     'NULL' `
    -Description     "$($ModuleName)" `
    -Tags          @('CyberCondor','New-IconFile','New-CircularIcon')`
    -ProjectUri      'https://github.com/CyberCondor/New-CircularIcon' `
    -HelpInfoURI     'https://github.com/CyberCondor/New-CircularIcon' `
    -NestedModules @(
    )`
    -RequiredModules @(
    )`
    -PowerShellVersion     '5.1' `
    -PowerShellHostName    '' `
    -ProcessorArchitecture 'None' `
    -CmdletsToExport      @() `
    -ModuleList           @("$($ModuleName).psm1") `
    -FileList             @("$($ModuleName).psm1","$($ModuleName).psd1") `
    -FunctionsToExport    @('New-CircularIcon') `
    -AliasesToExport      @('New-IconFile') `
    -ReleaseNotes "Initial Public Release" `
    -LicenseUri 'https://github.com/CyberCondor/New-CircularIcon/blob/main/LICENSE'