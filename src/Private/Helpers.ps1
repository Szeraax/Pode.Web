function Get-PodeWebTemplatePath
{
    $path = Split-Path -Parent -Path ((Get-Module -Name 'Pode.Web' | Sort-Object -Property Version -Descending | Select-Object -First 1).Path)
    return (Join-PodeWebPath $path 'Templates')
}

function Get-PodeWebAuthData
{
    $authData = $WebEvent.Auth
    if (($null -eq $authData) -or ($authData.Count -eq 0)) {
        $authData = $WebEvent.Session.Data.Auth
    }

    return $authData
}

function Get-PodeWebAuthUsername
{
    param(
        [Parameter()]
        $AuthData
    )

    # nothing if no auth data
    if (($null -eq $AuthData) -or ($null -eq $AuthData.User)) {
        return [string]::Empty
    }

    $user = $AuthData.User

    # check username prop
    $prop = (Get-PodeWebState -Name 'auth-props').Username
    if (![string]::IsNullOrWhiteSpace($prop) -and ![string]::IsNullOrWhiteSpace($user.$prop)) {
        return $user.$prop
    }

    # name
    if (![string]::IsNullOrWhiteSpace($user.Name)) {
        return $user.Name
    }

    # full name
    if (![string]::IsNullOrWhiteSpace($user.FullName)) {
        return $user.FullName
    }

    # username
    if (![string]::IsNullOrWhiteSpace($user.Username)) {
        return $user.Username
    }

    # email - split on @ though
    if (![string]::IsNullOrWhiteSpace($user.Email)) {
        return ($user.Email -split '@')[0]
    }

    # nothing
    return [string]::Empty
}

function Get-PodeWebAuthGroups
{
    param(
        [Parameter()]
        $AuthData
    )

    # nothing if no auth data
    if (($null -eq $AuthData) -or ($null -eq $AuthData.User)) {
        return @()
    }

    $user = $AuthData.User

    # check group prop
    $prop = (Get-PodeWebState -Name 'auth-props').Group
    if (![string]::IsNullOrWhiteSpace($prop) -and !(Test-PodeWebArrayEmpty -Array $user.$prop)) {
        return @($user.$prop)
    }

    # groups
    if (!(Test-PodeWebArrayEmpty -Array $user.Groups)) {
        return @($user.Groups)
    }

    # roles
    if (!(Test-PodeWebArrayEmpty -Array $user.Roles)) {
        return @($user.Roles)
    }

    # scopes
    if (!(Test-PodeWebArrayEmpty -Array $user.Scopes)) {
        return @($user.Scopes)
    }

    # nothing
    return @()
}

function Get-PodeWebAuthAvatarUrl
{
    param(
        [Parameter()]
        $AuthData
    )

    # nothing if no auth data
    if (($null -eq $AuthData) -or ($null -eq $AuthData.User)) {
        return [string]::Empty
    }

    $user = $AuthData.User

    # nothing if no property set
    $prop = (Get-PodeWebState -Name 'auth-props').Avatar
    if (![string]::IsNullOrWhiteSpace($prop) -and ![string]::IsNullOrWhiteSpace($user.$prop)) {
        return (Add-PodeWebAppPath -Url $user.$prop)
    }

    # avatar url
    if (![string]::IsNullOrWhiteSpace($user.AvatarUrl)) {
        return (Add-PodeWebAppPath -Url $user.AvatarUrl)
    }

    return [string]::Empty
}

function Get-PodeWebAuthTheme
{
    param(
        [Parameter()]
        $AuthData
    )

    # nothing if no auth data
    if (($null -eq $AuthData) -or ($null -eq $AuthData.User)) {
        return $null
    }

    $user = $AuthData.User

    # nothing if no property set
    $prop = (Get-PodeWebState -Name 'auth-props').Theme
    if (![string]::IsNullOrWhiteSpace($prop) -and ![string]::IsNullOrWhiteSpace($user.$prop)) {
        return $user.$prop
    }

    # theme
    if (![string]::IsNullOrWhiteSpace($user.Theme)) {
        return $user.Theme
    }

    return [string]::Empty
}

function Get-PodeWebInbuiltThemes
{
    return @('Auto', 'Light', 'Dark', 'Terminal', 'Custom')
}

function Test-PodeWebThemeCustom
{
    param(
        [Parameter()]
        [string]
        $Name
    )

    $customThemes = Get-PodeWebState -Name 'custom-themes'
    return ($customThemes.Themes.Keys -icontains $Name)
}

function Test-PodeWebThemeInbuilt
{
    param(
        [Parameter()]
        [string]
        $Name
    )

    $inbuildThemes = Get-PodeWebInbuiltThemes
    return ($Name -iin $inbuildThemes)
}

function Test-PodeWebArrayEmpty
{
    param(
        [Parameter()]
        $Array
    )

    return (($null -eq $Array) -or (@($Array).Length -eq 0))
}

function Test-PodeWebPageAccess
{
    param(
        [Parameter()]
        $PageAccess,

        [Parameter()]
        $Auth
    )

    $hasGroups = (!(Test-PodeWebArrayEmpty -Array $PageAccess.Groups))
    $hasUsers = (!(Test-PodeWebArrayEmpty -Array $PageAccess.Users))

    # if page has no access restriction, just return
    if (!$hasGroups -and !$hasUsers) {
        return $true
    }

    # check groups
    if ($hasGroups -and !(Test-PodeWebArrayEmpty -Array $Auth.Groups)) {
        foreach ($group in $PageAccess.Groups) {
            if ($Auth.Groups -icontains $group) {
                return $true
            }
        }
    }

    # check users
    if ($hasUsers -and ![string]::IsNullOrWhiteSpace($Auth.Username)) {
        if ($PageAccess.Users -icontains $Auth.Username) {
            return $true
        }
    }

    return $false
}

function Write-PodeWebViewResponse
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [hashtable]
        $Data = @{}
    )

    $Data['AppPath'] = (Get-PodeWebState -Name 'app-path')
    Write-PodeViewResponse -Path "$($Path).pode" -Data $Data -Folder 'pode.web.views' -FlashMessages
}

function Add-PodeWebAppPath
{
    param(
        [Parameter()]
        [string]
        $Url
    )

    if (![string]::IsNullOrWhiteSpace($Url) -and $Url.StartsWith('/')) {
        $appPath = Get-PodeWebState -Name 'app-path'
        $Url = "$($appPath)$($Url)"
    }

    return $Url
}

function Use-PodeWebPartialView
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [hashtable]
        $Data = @{}
    )

    Use-PodePartialView -Path "$($Path).pode" -Data $Data -Folder 'pode.web.views'
}

function Set-PodeWebState
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [object]
        $Value
    )

    Set-PodeState -Name "pode.web.$($Name)" -Value $Value -Scope 'pode.web' | Out-Null
}

function Get-PodeWebState
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return (Get-PodeState -Name "pode.web.$($Name)")
}

function Get-PodeWebHomeName
{
    $name = (Get-PodeWebState -Name 'pages')['/'].DisplayName
    if ([string]::IsNullOrWhiteSpace($name)) {
        return 'Home'
    }

    return $name
}

function Get-PodeWebHomeIcon
{
    $icon = (Get-PodeWebState -Name 'pages')['/'].Icon
    if ([string]::IsNullOrWhiteSpace($icon)) {
        return 'home'
    }

    return $icon
}

function Get-PodeWebCookie
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return (Get-PodeCookie -Name "pode.web.$($Name)")
}

function Get-PodeWebRandomName
{
    param(
        [Parameter()]
        [int]
        $Length = 5
    )

    $r =  [System.Random]::new()
    return [string]::Concat(@(foreach ($i in 1..$Length) {
        [char]$r.Next(65, 90)
    }))
}

function Protect-PodeWebName
{
    param(
        [Parameter()]
        [string]
        $Name
    )

    return ($Name -ireplace '[^a-z0-9_]', '').Trim()
}

function Protect-PodeWebSpecialCharacters
{
    param(
        [Parameter()]
        [string]
        $Value
    )

    return ($Value -replace "[\s!`"#\$%&'\(\)*+,\./:;<=>?@\[\\\]^``{\|}~]", '_')
}

function Protect-PodeWebValue
{
    param(
        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Default,

        [switch]
        $Encode
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($Encode) {
            return [System.Net.WebUtility]::HtmlEncode($Default)
        }
        else {
            return $Default
        }
    }

    if ($Encode) {
        return [System.Net.WebUtility]::HtmlEncode($Value)
    }
    else {
        return $Value
    }
}

function Protect-PodeWebValues
{
    param(
        [Parameter()]
        [string[]]
        $Value,

        [Parameter()]
        [string[]]
        $Default,

        [switch]
        $EqualCount,

        [switch]
        $Encode
    )

    if (($null -eq $Value) -or ($Value.Length -eq 0)) {
        if ($Encode -and ($null -ne $Default) -and ($Default.Length -gt 0)) {
            return @(foreach ($v in $Default) {
                [System.Net.WebUtility]::HtmlEncode($v)
            })
        }
        else {
            return $Default
        }
    }

    if ($EqualCount -and ($Value.Length -ne $Default.Length)) {
        throw "Expected an equal number of values in both arrays"
    }

    if ($Encode) {
        return @(foreach ($v in $Value) {
            [System.Net.WebUtility]::HtmlEncode($v)
        })
    }
    else {
        return $Value
    }
}

function Test-PodeWebRoute
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
    )

    $route = (Get-PodeRoute -Method Post -Path $Path)

    if ([string]::IsNullOrWhiteSpace($PageData.Name) -and [string]::IsNullOrWhiteSpace($ElementData.Name) -and ($null -ne $route)) {
        throw "An element with ID '$(Split-Path -Path $Path -Leaf)' already exists"
    }

    return ($null -ne $route)
}

function Get-PodeWebElementId
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Tag,

        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Name
    )

    if (![string]::IsNullOrWhiteSpace($Id)) {
        return $Id
    }

    # prepend the parent element's ID
    $_id = [string]::Empty
    if (![string]::IsNullOrWhiteSpace($ElementData.ID)) {
        $_id = "$($ElementData.ID)_"
    }
    elseif (![string]::IsNullOrWhiteSpace($ElementData.Name)) {
        $_id = "$($ElementData.Name)_"
    }

    # start with element tag
    $_id += "$($Tag)"

    # add page name and group if we have one
    if (![string]::IsNullOrWhiteSpace($PageData.Name)) {
        $_id += "_$($PageData.Name)"
    }

    if (![string]::IsNullOrWhiteSpace($PageData.Group)) {
        $_id += "_$($PageData.Group)"
    }

    # add name if we have one, or a random name
    if (![string]::IsNullOrWhiteSpace($Name)) {
        $_id += "_$($Name)"
    }
    else {
        $_id += "_$(Get-PodeWebRandomName)"
    }

    $_id = Protect-PodeWebName -Name $_id
    return ($_id -replace '\s+', '_').ToLowerInvariant()
}

function Convert-PodeWebAlertTypeToClass
{
    param(
        [Parameter()]
        [string]
        $Type
    )

    $map = @{
        error       = 'danger'
        warning     = 'warning'
        tip         = 'success'
        success     = 'success'
        note        = 'secondary'
        info        = 'info'
        important   = 'primary'
    }

    if ($map.ContainsKey($Type)) {
        return $map[$Type]
    }

    return 'primary'
}

function Convert-PodeWebAlertTypeToIcon
{
    param(
        [Parameter()]
        [string]
        $Type
    )

    $map = @{
        error       = 'alert-circle'
        warning     = 'alert'
        tip         = 'thumb-up'
        success     = 'check-circle'
        note        = 'book-open'
        info        = 'information'
        important   = 'bell'
    }

    if ($map.ContainsKey($Type)) {
        return $map[$Type]
    }

    return 'bell'
}

function Convert-PodeWebColourToClass
{
    param(
        [Parameter()]
        [string]
        $Colour
    )

    $map = @{
        blue    = 'primary'
        green   = 'success'
        grey    = 'secondary'
        red     = 'danger'
        yellow  = 'warning'
        cyan    = 'info'
        light   = 'light'
        dark    = 'dark'
    }

    if ($map.ContainsKey($Colour)) {
        return $map[$Colour]
    }

    return 'primary'
}

function Convert-PodeWebButtonSizeToClass
{
    param(
        [Parameter()]
        [string]
        $Size,

        [switch]
        $FullWidth,

        [switch]
        $Group
    )

    $css = (@{
        small = 'btn-sm'
        large = 'btn-lg'
    })[$Size]

    if ($Group) {
        $css = $css -replace 'btn-', 'btn-group-'
    }

    if ($FullWidth) {
        $css += ' btn-block'
    }

    return $css
}

function Test-PodeWebContent
{
    param(
        [Parameter()]
        [hashtable[]]
        $Content,

        [Parameter()]
        [string[]]
        $ComponentType,

        [Parameter()]
        [string[]]
        $ObjectType
    )

    # if no content, then it's true
    if (Test-PodeWebArrayEmpty -Array $Content) {
        return $true
    }

    # ensure the content ComponentTypes are correct
    if (!(Test-PodeWebArrayEmpty -Array $ComponentType)) {
        foreach ($item in $Content) {
            if ($item.ComponentType -inotin $ComponentType) {
                return $false
            }
        }
    }

    # ensure the content elements are correct
    if (!(Test-PodeWebArrayEmpty -Array $ObjectType)) {
        foreach ($item in $Content) {
            if ($item.ObjectType -inotin $ObjectType) {
                return $false
            }
        }
    }

    return $true
}

function Remove-PodeWebRoute
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Method,

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    if (Test-PodeIsEmpty $EndpointName) {
        Remove-PodeRoute -Method $Method -Path $Path
    }
    else {
        foreach ($endpoint in $EndpointName) {
            Remove-PodeRoute -Method $Method -Path $Path -EndpointName $endpoint
        }
    }
}

function Test-PodeWebOutputWrapped
{
    param(
        [Parameter()]
        $Output
    )

    if ($null -eq $Output) {
        return $false
    }

    if ($Output -is [array]) {
        $Output = $Output[0]
    }

    return (($Output -is [hashtable]) -and ![string]::IsNullOrWhiteSpace($Output.Operation) -and ![string]::IsNullOrWhiteSpace($Output.ObjectType))
}

function Get-PodeWebFirstPublicPage
{
    $pages = Get-PodeWebState -Name 'pages'
    if (($null -eq $pages) -or ($pages.Count -eq 0)) {
        return $null
    }

    foreach ($page in ($pages.Values | Sort-Object -Property { $_.Group }, { $_.Name })) {
        if ($page.IsSystem) {
            continue
        }

        if ((Test-PodeWebArrayEmpty -Array $page.Access.Groups) -and (Test-PodeWebArrayEmpty -Array $page.Access.Users)) {
            return $page
        }
    }

    return $null
}

function Get-PodeWebPagePath
{
    [CmdletBinding(DefaultParameterSetName='Name')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Name')]
        [string]
        $Name,

        [Parameter(ParameterSetName='Name')]
        [string]
        $Group,

        [Parameter(ParameterSetName='Page')]
        [hashtable]
        $Page,

        [switch]
        $NoAppPath
    )

    $path = [string]::Empty

    if ($null -ne $Page) {
        $Name = $Page.Name
        $Group = $Page.Group
    }

    $Name = Protect-PodeWebSpecialCharacters -Value $Name
    $Group = Protect-PodeWebSpecialCharacters -Value $Group

    if (![string]::IsNullOrWhiteSpace($Group)) {
        $path += "/groups/$($Group)"
    }

    $path += "/pages/$($Name)"

    if (!$NoAppPath) {
        $path = (Add-PodeWebAppPath -Url $path)
    }

    return $path
}

function ConvertTo-PodeWebEvents
{
    param(
        [Parameter()]
        [string[]]
        $Events
    )

    $js_events = [string]::Empty

    if (($null -eq $Events) -or ($Events.Length -eq 0)) {
        return $js_events
    }

    foreach ($evt in $Events) {
        $js_events += " on$($evt)=`"invokeEvent('$($evt)', this);`""
    }

    return $js_events
}

function Protect-PodeWebRange
{
    param(
        [Parameter()]
        [string]
        $Value,

        [Parameter(Mandatory=$true)]
        [int]
        $Min,

        [Parameter(Mandatory=$true)]
        [int]
        $Max
    )

    # null for no value
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $pattern = Get-PodeWebNumberRegex

    # if it's a percentage, calculate value
    if ($Value.EndsWith('%')) {
        $_val = [double]$Value.TrimEnd('%')
        $Value = $Max * $_val * 0.01
    }

    # if value is number, check range
    if ($Value -match $pattern) {
        $_val = [int]$Value

        if ($_val -lt $Min) {
            return $Min
        }

        if ($_val -gt $Max) {
            return $Max
        }

        return $_val
    }

    # invalid value
    throw "Invalid value supplied for range: $($Value). Expected a value between $($Min)-$($Max), or a percentage."
}

function ConvertTo-PodeWebSize
{
    param(
        [Parameter()]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Default = 0,

        [Parameter(Mandatory=$true)]
        [ValidateSet('px', '%', 'em')]
        [string]
        $Type,

        [switch]
        $AllowNull
    )

    if ($AllowNull -and [string]::IsNullOrEmpty($Value)) {
        return $null
    }

    $pattern = Get-PodeWebNumberRegex
    $defIsNumber = ($Default -match $pattern)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($defIsNumber) {
            return "$($Default)$($Type)"
        }
        else {
            return $Default
        }
    }

    if ($Value -match $pattern) {
        $_val = [double]$Value
        if ($_val -le 0) {
            if ($defIsNumber) {
                $Value = $Default
            }
            else {
                return $Default
            }
        }
        elseif (($Type -eq '%') -and ($_val -gt 100)) {
            $Value = 100
        }

        return "$($Value)$($Type)"
    }

    return $Value
}

function Get-PodeWebNumberRegex
{
    return '^\-?\d+(\.\d+){0,1}$'
}

function Set-PodeWebSecurity
{
    param(
        [Parameter()]
        [ValidateSet('None', 'Default', 'Simple', 'Strict')]
        [string]
        $Security,

        [switch]
        $UseHsts
    )

    if ($Security -ieq 'none') {
        Remove-PodeSecurity
        return
    }

    switch ($Security.ToLowerInvariant()) {
        'default' {
            Set-PodeSecurity -Type Simple -UseHsts:$UseHsts
            Remove-PodeSecurityCrossOrigin

            Add-PodeSecurityContentSecurityPolicy `
                -Default 'http', 'https' `
                -Style 'http', 'https' `
                -Scripts 'http', 'https' `
                -Image 'http', 'https'
        }

        'simple' {
            Set-PodeSecurity -Type Simple -UseHsts:$UseHsts
        }

        'strict' {
            Set-PodeSecurity -Type Strict -UseHsts:$UseHsts
        }
    }

    Add-PodeSecurityContentSecurityPolicy `
        -Style 'self', 'unsafe-inline' `
        -Scripts 'self', 'unsafe-inline' `
        -Image 'self', 'data'
}

function Test-PodeWebParameter
{
    param(
        [Parameter(Mandatory=$true)]
        $Parameters,

        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        $Value
    )

    if ($Parameters.ContainsKey($Name)) {
        return $Value
    }

    return $null
}

function Protect-PodeWebIconType
{
    param(
        [Parameter()]
        [object]
        $Icon,

        [Parameter(Mandatory=$true)]
        [string]
        $Element
    )

    # just null or string
    if (($null -eq $Icon) -or ($Icon -is [string])) {
        return $Icon
    }

    # if hashtable, check object type
    if (($Icon -is [hashtable]) -and ($Icon.ObjectType -ieq 'icon')) {
        return $Icon
    }

    # error
    throw "Icon for '$($Element)' is not a string or hashtable from New-PodeWebIcon"
}

function Protect-PodeWebIconPreset
{
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Icon,

        [Parameter()]
        [hashtable]
        $Preset
    )

    if (($null -eq $Preset) -or ($Preset.Length -eq 0)) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Preset.Name)) {
        $Preset.Name = $Icon.Name
    }

    if ([string]::IsNullOrWhiteSpace($Preset.Colour)) {
        $Preset.Colour = $Icon.Colour
    }

    if ([string]::IsNullOrWhiteSpace($Preset.Title)) {
        $Preset.Title = $Icon.Title
    }

    if ([string]::IsNullOrWhiteSpace($Preset.Flip)) {
        $Preset.Flip = $Icon.Flip
    }

    if ($Preset.Rotate -le -1) {
        $Preset.Rotate = $Icon.Rotate
    }

    if ($Preset.Size -le -1) {
        $Preset.Size = $Icon.Size
    }

    if ($null -eq $Preset.Spin) {
        $Preset.Spin = $Icon.Spin
    }

    return $Preset
}