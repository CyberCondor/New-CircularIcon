#Requires -Version 5.1

<#
.SYNOPSIS
    PowerShell module for creating circular icon files with optional colored border rings.

.DESCRIPTION
    This module provides the New-CircularIcon function to convert square images into 
    circular icons with customizable colored border rings. Supports common image formats 
    and outputs PNG files suitable for favicons or icons.
#>

# Load required assemblies
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
}
catch {
    throw "Failed to load System.Drawing assembly: $_"
}

# Private functions (not exported)
function Get-SafePath {
    param([string]$Path)
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Path cannot be empty"
    }
    
    # Remove surrounding quotes if present
    $cleanPath = $Path.Trim('"', "'")
    
    try {
        # Use PowerShell's Resolve-Path for relative paths, fallback to GetFullPath for new paths
        if (Test-Path $cleanPath) {
            $resolved = (Resolve-Path $cleanPath).Path
        } else {
            # For non-existent paths, combine with current location
            if ([System.IO.Path]::IsPathRooted($cleanPath)) {
                $resolved = [System.IO.Path]::GetFullPath($cleanPath)
            } else {
                # Relative path - combine with PowerShell's current location
                $resolved = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).Path, $cleanPath))
            }
        }
            
        if ($cleanPath.Contains([char]0)) {
            throw "Path contains null bytes"
        }
        return $resolved
    }
    catch {
        throw "Invalid path: $cleanPath"
    }
}

function Test-ImageFile {
    param(
        [string]$FilePath,
        [switch]$Quiet
    )
    
    if (!(Test-Path $FilePath)) {
        throw "File does not exist: $FilePath"
    }
    
    $fileInfo = Get-Item $FilePath
    if ($fileInfo.Length -gt 50MB) {
        throw "File too large: $([math]::Round($fileInfo.Length/1MB,1))MB (max 50MB)"
    }
    
    if ($fileInfo.Length -eq 0) {
        throw "File is empty"
    }
    
    # Magic byte validation - check actual file format
    $magicBytes = @{
        # JPEG/JPG - FF D8 FF
        'jpeg' = @(@(0xFF, 0xD8, 0xFF), @('.jpg', '.jpeg'))
        # PNG - 89 50 4E 47 0D 0A 1A 0A
        'png' = @(@(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A), @('.png'))
        # GIF - GIF87a (47 49 46 38 37 61) or GIF89a (47 49 46 38 39 61)
        'gif87' = @(@(0x47, 0x49, 0x46, 0x38, 0x37, 0x61), @('.gif'))
        'gif89' = @(@(0x47, 0x49, 0x46, 0x38, 0x39, 0x61), @('.gif'))
        # BMP - BM (42 4D)
        'bmp' = @(@(0x42, 0x4D), @('.bmp'))
        # TIFF - II (49 49 2A 00) little-endian or MM (4D 4D 00 2A) big-endian
        'tiff_le' = @(@(0x49, 0x49, 0x2A, 0x00), @('.tiff', '.tif'))
        'tiff_be' = @(@(0x4D, 0x4D, 0x00, 0x2A), @('.tiff', '.tif'))
        # ICO - 00 00 01 00
        'ico' = @(@(0x00, 0x00, 0x01, 0x00), @('.ico'))
    }
    
    # Read the first bytes of the file for magic byte checking
    $stream = $null
    $reader = $null
    $detectedFormat = $null
    $validExtensionsForFormat = @()
    
    try {
        $stream = [System.IO.File]::OpenRead($FilePath)
        $reader = New-Object System.IO.BinaryReader($stream)
        
        # Read enough bytes to check all magic signatures (max 8 bytes needed)
        $headerBytes = $reader.ReadBytes(8)
        
        if ($headerBytes.Length -lt 2) {
            throw "File too small to be a valid image"
        }
        
        # Check against known magic bytes
        foreach ($format in $magicBytes.Keys) {
            $signature = $magicBytes[$format][0]
            $extensions = $magicBytes[$format][1]
            
            if ($headerBytes.Length -ge $signature.Length) {
                $match = $true
                for ($i = 0; $i -lt $signature.Length; $i++) {
                    if ($headerBytes[$i] -ne $signature[$i]) {
                        $match = $false
                        break
                    }
                }
                
                if ($match) {
                    $detectedFormat = $format
                    $validExtensionsForFormat = $extensions
                    break
                }
            }
        }
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($stream) { $stream.Close() }
    }
    
    # Verify format was detected
    if (-not $detectedFormat) {
        throw "File format not recognized - file may be corrupted or not a valid image"
    }
    
    # Check if file extension matches the detected format
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($ext -notin $validExtensionsForFormat) {
        throw "File extension '$ext' does not match detected format (detected: $($validExtensionsForFormat -join ' or '))"
    }
    
    # Additional validation using System.Drawing
    try {
        $img = [System.Drawing.Image]::FromFile($FilePath)
        
        if ($img.Width -eq 0 -or $img.Height -eq 0) {
            $img.Dispose()
            throw "Invalid dimensions"
        }
        
        if (($img.Width * $img.Height) -gt 100000000) {
            $img.Dispose()
            throw "Image too large (max 100M pixels)"
        }
        
        if ($img.PixelFormat -eq [System.Drawing.Imaging.PixelFormat]::Format32bppCmyk) {
            if (-not $Quiet) {
                Write-Warning "CMYK detected - colors may not convert accurately"
            }
        }
        
        if ($ext -eq '.gif') {
            $frameCount = $img.GetFrameCount([System.Drawing.Imaging.FrameDimension]::Time)
            if ($frameCount -gt 1) {
                if (-not $Quiet) {
                    Write-Warning "Animated GIF detected - only first frame will be used"
                }
            }
        }
        
        $img.Dispose()
    }
    catch {
        throw "Cannot load image: $($_.Exception.Message)"
    }
}

function Test-Colors {
    param([string[]]$ColorArray)
    
    if ($ColorArray.Count -gt 20) {
        throw "Too many colors (max 20)"
    }
    
    foreach ($color in $ColorArray) {
        if ([string]::IsNullOrWhiteSpace($color)) {
            throw "Empty color value"
        }
        if ($color -notmatch '^#[0-9A-Fa-f]{6}$') {
            throw "Invalid color format: $color (use #RRGGBB)"
        }
    }
}

function Get-OutputPath {
    param(
        [string]$RequestedPath,
        [switch]$Quiet
    )
    
    if ([string]::IsNullOrWhiteSpace($RequestedPath)) {
        # Try to find the actual Downloads folder
        $possiblePaths = @(
            "$($env:USERPROFILE + '\Downloads')"
        )
        
        $downloads = $null
        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $downloads = $path
                break
            }
        }
        
        # If we can't find Downloads, use current directory
        if ($downloads -eq $null) {
            $downloads = Get-Location
            if (-not $Quiet) {
                Write-Warning "Could not locate Downloads folder, using current directory: $downloads"
            }
        }
        
        $baseName = 'icon'
        $counter = 1
        
        do {
            $fileName = "${baseName}_${counter}.png"
            $fullPath = Join-Path $downloads $fileName
            $counter++
        } while ((Test-Path $fullPath) -and $counter -lt 1000)
        
        return $fullPath
    }
    else {
        # Check if the requested path is a directory
        $isDirectory = $false
        
        if (Test-Path $RequestedPath -PathType Container) {
            # It's an existing directory
            $isDirectory = $true
        } elseif (-not [System.IO.Path]::HasExtension($RequestedPath)) {
            # No extension and doesn't exist - might be intended as directory
            # But only treat as directory if it ends with a separator or is . or ..
            if ($RequestedPath -match '[/\\]$' -or $RequestedPath -eq '.' -or $RequestedPath -eq '..') {
                $isDirectory = $true
            }
        }
        
        if ($isDirectory) {
            # User provided a directory - generate filename in that directory
            # Resolve the directory path properly
            if ($RequestedPath -eq '.') {
                $dir = Get-Location | Select-Object -ExpandProperty Path
            } elseif ($RequestedPath -eq '..') {
                $dir = Get-Item .. | Select-Object -ExpandProperty FullName
            } else {
                $dir = Resolve-Path $RequestedPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path
                if (-not $dir) {
                    # Directory doesn't exist, try to create it
                    $dir = $RequestedPath
                }
            }
            
            $baseName = 'icon'
            $counter = 1
            
            do {
                $fileName = "${baseName}_${counter}.png"
                $fullPath = Join-Path $dir $fileName
                $counter++
            } while ((Test-Path $fullPath) -and $counter -lt 1000)
            
            return $fullPath
        }
        else {
            # User provided a file path
            if (!(Test-Path $RequestedPath)) {
                # File doesn't exist - use as-is
                return $RequestedPath
            }
            
            # File exists - add number suffix
            $dir = [System.IO.Path]::GetDirectoryName($RequestedPath)
            if ([string]::IsNullOrEmpty($dir)) {
                $dir = Get-Location | Select-Object -ExpandProperty Path
            }
            
            $name = [System.IO.Path]::GetFileNameWithoutExtension($RequestedPath)
            $ext = [System.IO.Path]::GetExtension($RequestedPath)
            
            # Ensure extension is .png if not specified
            if ([string]::IsNullOrEmpty($ext)) {
                $ext = '.png'
            }
            
            $counter = 1
            do {
                $newName = "${name}_${counter}${ext}"
                $newPath = Join-Path $dir $newName
                $counter++
            } while ((Test-Path $newPath) -and $counter -lt 1000)
            
            return $newPath
        }
    }
}

function ConvertTo-Base64Icon {
    param([string]$FilePath)
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        return "data:image/png;base64,$([Convert]::ToBase64String($bytes))"
    }
    catch {
        throw "Failed to convert to base64: $($_.Exception.Message)"
    }
}

function New-CircularIconInternal {
    param(
        [string]$InputPath,
        [string]$OutputPath,
        [string[]]$Colors,
        [int]$BorderWidth,
        [int]$Size
    )
    
    $originalImage = $null
    $finalBitmap = $null
    $graphics = $null
    $path = $null
    $solidBrush = $null
    
    try {
        # Create canvas at final size to avoid resizing artifacts
        $canvasSize = $Size
        $finalBitmap = New-Object System.Drawing.Bitmap($canvasSize, $canvasSize)
        $graphics = [System.Drawing.Graphics]::FromImage($finalBitmap)
        
        # Use highest quality settings for smooth circles
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        
        # Clear with transparent background
        $graphics.Clear([System.Drawing.Color]::Transparent)
        
        # Calculate sizes to fit within canvas with proper margins
        $totalBorderWidth = $BorderWidth * $Colors.Count
        $margin = $totalBorderWidth + 2
        $imageSize = $canvasSize - (2 * $margin)
        $imageOffset = $margin
        
        # Ensure we have room for at least a small circle
        if ($imageSize -lt 4) {
            $margin = 1
            $imageSize = $canvasSize - 2
            $imageOffset = 1
        }
        
        if ([string]::IsNullOrWhiteSpace($InputPath)) {
            # Create solid color circle when no input image
            $solidColor = [System.Drawing.ColorTranslator]::FromHtml("#ee4e04")
            $solidBrush = New-Object System.Drawing.SolidBrush($solidColor)
            
            # Draw filled circle with antialiasing
            $graphics.FillEllipse($solidBrush, $imageOffset, $imageOffset, $imageSize, $imageSize)
        }
        else {
            # Load and draw image
            $originalImage = [System.Drawing.Image]::FromFile($InputPath)
            
            # Draw circular image
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddEllipse($imageOffset, $imageOffset, $imageSize, $imageSize)
            $graphics.SetClip($path)
            
            # Calculate source rectangle from original image
            $srcSize = [Math]::Min($originalImage.Width, $originalImage.Height)
            $srcX = ($originalImage.Width - $srcSize) / 2
            $srcY = ($originalImage.Height - $srcSize) / 2
            
            $destRect = New-Object System.Drawing.Rectangle($imageOffset, $imageOffset, $imageSize, $imageSize)
            $srcRect = New-Object System.Drawing.Rectangle($srcX, $srcY, $srcSize, $srcSize)
            $graphics.DrawImage($originalImage, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
            
            # Reset clipping for borders
            $graphics.ResetClip()
        }
        
        # Draw borders
        for ($i = 0; $i -lt $Colors.Count; $i++) {
            $color = [System.Drawing.ColorTranslator]::FromHtml($Colors[$i])
            $pen = New-Object System.Drawing.Pen($color, $BorderWidth)
            $pen.Alignment = [System.Drawing.Drawing2D.PenAlignment]::Center
            
            # Calculate ring position - work outward from center
            $ringSize = $imageSize + (2 * ($i + 1) * $BorderWidth)
            $ringOffset = ($canvasSize - $ringSize) / 2
            
            # Ensure ring fits within canvas
            if ($ringOffset -ge 0 -and ($ringOffset + $ringSize) -le $canvasSize) {
                $graphics.DrawEllipse($pen, $ringOffset, $ringOffset, $ringSize, $ringSize)
            }
            
            $pen.Dispose()
        }
        
        # Save directly without resizing
        $finalBitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        
        return $OutputPath
    }
    finally {
        if ($solidBrush) { $solidBrush.Dispose() }
        if ($graphics) { $graphics.Dispose() }
        if ($finalBitmap) { $finalBitmap.Dispose() }
        if ($originalImage) { $originalImage.Dispose() }
        if ($path) { $path.Dispose() }
    }
}

# Public function (exported)
function New-CircularIcon {
    <#
    .SYNOPSIS
        Creates circular icon files with optional colored border rings from input images.

    .DESCRIPTION
        This function converts square images into circular icons with customizable colored border rings.
        Supports common image formats and outputs PNG files suitable for favicons or icons.
        If no input image is provided, creates a solid #ee4e04 colored circle.

    .PARAMETER InputPath
        Optional path to the input image file. If not provided, creates a solid #ee4e04 circle.

    .PARAMETER OutputPath
        Optional path where the output PNG file will be saved. If not provided, defaults to icon_1.png in Downloads folder.

    .PARAMETER Colors
        Optional single hex color or array of hex color codes for border rings (e.g., "#FF0000" or @("#FF0000", "#00FF00")).
        If not provided, creates circular crop without rings.

    .PARAMETER BorderWidth
        Width of each colored border ring in pixels. Default is 3. Range is 1-10

    .PARAMETER Size
        Final size of the icon in pixels. Default is 32. Range is 16, 24, 32, 48, 64, 128.

    .PARAMETER AsBase64
        Switch to return the base64 encoded string of the generated icon.

    .PARAMETER PassThru
        Returns the output file path or base64 string to the pipeline.

    .PARAMETER Quiet
        Suppresses all console output except errors.

    .EXAMPLE
        New-CircularIcon
        Creates a solid #ee4e04 circle with no borders

    .EXAMPLE
        New-CircularIcon -InputPath "image.jpg"
        Creates a circular icon from the image

    .EXAMPLE
        New-CircularIcon -InputPath "image.jpg" -Colors @("#008080", "#663399")
        Creates a circular icon with colored border rings

    .EXAMPLE
        New-CircularIcon -AsBase64 -PassThru
        Creates a solid circle and returns base64 string
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$InputPath = "",
        
        [Parameter(Position = 1)]
        [string]$OutputPath = "",
        
        [Parameter()]
        [string[]]$Colors = @(),
        
        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$BorderWidth = 3,
        
        [Parameter()]
        [ValidateSet(16, 24, 32, 48, 64, 128)]
        [int]$Size = 32,
        
        [Parameter()]
        [Alias("ReturnBase64")]
        [switch]$AsBase64,

        [Parameter(Mandatory = $false)]
        [Alias("h", "?")]
        [switch]$Help,
        
        [Parameter()]
        [switch]$PassThru,
        
        [Parameter()]
        [Alias("Silent", "q")]
        [switch]$Quiet
    )
    # Handle Help parameter
    if ($Help) {
        Get-Help New-CircularIcon -Full
        break
    }
    
    try {
        # Handle null or empty InputPath
        if ($null -eq $InputPath) {
            $InputPath = ""
        }
        
        # Validate input only if provided
        if (![string]::IsNullOrWhiteSpace($InputPath)) {
            $validatedInputPath = Get-SafePath $InputPath
            Test-ImageFile -FilePath $validatedInputPath -Quiet:$Quiet
        } else {
            $validatedInputPath = ""
        }
        
        # Validate colors
        Test-Colors $Colors
        
        # Determine if we're using a temporary file
        $usingTempFile = $false
        $tempFile = $null
        
        # Get output path - use temp file if AsBase64 is set and no OutputPath specified
        if ($AsBase64 -and [string]::IsNullOrWhiteSpace($OutputPath)) {
            # Create a temporary file for base64 conversion
            $tempFile = [System.IO.Path]::GetTempFileName()
            $outputPath = [System.IO.Path]::ChangeExtension($tempFile, ".png")
            $usingTempFile = $true
            
            # Delete the original temp file (we'll use the .png version)
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -Force
            }
        } else {
            # Normal output path handling
            $outputPath = Get-OutputPath -RequestedPath $OutputPath -Quiet:$Quiet
            $outputPath = Get-SafePath $outputPath
            
            # Ensure output directory exists
            $outputDir = [System.IO.Path]::GetDirectoryName($outputPath)
            if ($outputDir -and !(Test-Path $outputDir)) {
                New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
            }
        }
        
        if (-not $Quiet) {
            Write-Host "Creating circular icon..." -ForegroundColor Cyan
            if (![string]::IsNullOrWhiteSpace($validatedInputPath)) {
                Write-Host "Input: $validatedInputPath"
            } else {
                Write-Host "Input: None (solid #ee4e04 circle)"
            }
            
            # Only show output path if not using temp file
            if (-not $usingTempFile) {
                Write-Host "Output: $outputPath"
            } elseif ($AsBase64) {
                Write-Host "Output: Base64 string (no file saved)"
            }
            
            Write-Host "Size: ${Size}x${Size}"
            if ($Colors.Count -gt 0) {
                Write-Host "Colors: $($Colors -join ', ')"
            }
        }
        
        # Create icon
        $createdFile = New-CircularIconInternal -InputPath $validatedInputPath `
                                                -OutputPath $outputPath `
                                                -Colors $Colors `
                                                -BorderWidth $BorderWidth `
                                                -Size $Size
        
        if (-not $usingTempFile -and -not $Quiet) {
            Write-Host "Icon created successfully: $createdFile" -ForegroundColor Green
            
            # Get file size for info
            $fileInfo = Get-Item $createdFile
            Write-Host "File size: $([math]::Round($fileInfo.Length/1KB, 2)) KB"
        }
        
        if ($AsBase64) {
            $base64 = ConvertTo-Base64Icon $createdFile
            
            # Clean up temp file if we created one
            if ($usingTempFile -and (Test-Path $createdFile)) {
                Remove-Item $createdFile -Force
            }
            
            if (-not $Quiet) {
                Write-Host "`nBase64 string generated" -ForegroundColor Green
                if (-not $PassThru) {
                    Write-Host $base64
                    Write-Host "`nHTML usage:" -ForegroundColor Cyan
                    Write-Host "<link rel=`"icon`" type=`"image/png`" href=`"$base64`">"
                }
            }
            
            if ($PassThru -or $Quiet) {
                return $base64
            }
        } elseif ($PassThru -or $Quiet) {
            return $createdFile
        }
    }
    catch {
        # Clean up temp file on error if it exists
        if ($usingTempFile -and $outputPath -and (Test-Path $outputPath)) {
            Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

Set-Alias -Name New-IconFile -Value New-CircularIcon

Export-ModuleMember -Function New-CircularIcon -Alias New-IconFile
