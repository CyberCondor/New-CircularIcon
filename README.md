# New-CircularIcon
This function converts square images into circular icons with customizable colored border rings.
<br>Supports common image formats and outputs PNG files suitable for favicons or icons.
<br>If no input image is provided, creates a solid orange colored circle.

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

---

I made this to automate creation of icons to inject as Base64 into HTML, and packaged it up into a module for proper public release.

---

# Usage Examples

```PowerShell
New-CircularIcon
```

```PowerShell
New-IconFile
```

```PowerShell
New-IconFile -OutputPath .
```

```PowerShell
New-IconFile -InputPath "$($env:USERPROFILE + '\Downloads')\picture.jpg"
```

```PowerShell
New-IconFile -InputPath "picture.jpg" -Colors "#85B065"
```

```PowerShell
New-IconFile -InputPath "picture.jpg" -Colors @("#85B065","#85B376") -BorderWidth 2
```

```PowerShell
New-IconFile -InputPath "picture.jpg" -Colors @("#85B065","#85B376") -Size 64 -Quiet
```

```PowerShell
New-IconFile -InputPath "$($env:USERPROFILE + '\Downloads')\picture.jpg" -Colors @("#85B065","#85B376") -Size 16 -AsBase64
```

```PowerShell
New-IconFile -InputPath "picture.jpg" -Colors @("#85B065","#85B376") -BorderWidth 1 -Size 128 -AsBase64 -Quiet
```

```PowerShell
$colors = @("#85B065","#85B376","#381919","#ee4e04")
foreach($color in $colors){
    New-IconFile -InputPath "picture.jpg" -OutputPath .\ico.png -Colors $color -BorderWidth 1 -Size 64 -Quiet
}
```

```PowerShell
Write-Output "<link rel='icon' type='image/png' href=`"$(New-IconFile `
             -InputPath "$($env:USERPROFILE + '\Downloads')\squareicon.jpg" `
             -Colors @("#85B065","#85B376") `
             -BorderWidth 9 `
             -Size 64 `
             -AsBase64 `
             -Quiet)`">" | 
              Out-File htmlfile.html -Append -Encoding utf8
```


---

# Feature List

#### Core Functionality
- Circular Image Cropping - Converts square/rectangular images into perfect circles
- Solid Color Circle Generation - Creates a solid #ee4e04 colored circle when no input image is provided
- Multiple Colored Border Rings - Adds customizable colored rings around the circular image
- Multiple Output Formats - Outputs as PNG file or Base64 encoded string

#### Input/Output Features
- Flexible Input Support - Optional input image (creates solid circle if omitted)
- Multiple Image Format Support - JPG, JPEG, PNG, GIF, BMP, TIFF, TIF, ICO
- Magic Byte Validation - Verifies actual file format matches extension
- Automatic Output Path Generation - Defaults to Downloads folder with auto-incrementing names (icon_1.png, icon_2.png, etc.)
- Custom Output Path - Specify exact output location
- Collision Prevention - Automatically appends (1), (2), etc. to filenames if they already exist
- Relative Path Support - Properly handles relative paths like ".", "here", "./output.png"
- Base64 Output - Returns data URI string suitable for embedding in HTML/CSS

#### Image Processing Features
- High-Quality Antialiasing - Smooth edges on circles and borders
- Multiple Size Presets - 16, 24, 32, 48, 64, or 128 pixel output sizes
- Customizable Border Width - 1-10 pixels per ring
- Up to 20 Color Rings - Support for multiple concentric colored borders
- Smart Image Centering - Automatically centers and scales images to fit
- Aspect Ratio Preservation - Maintains proportions when cropping to circle

#### File Validation & Safety
- File Size Limits - Maximum 50MB input files
- Pixel Count Limits - Maximum 100 million pixels
- Empty File Detection - Prevents processing of 0-byte files
- Format Verification - Checks magic bytes to ensure file is actually an image
- Extension Validation - Verifies file extension matches detected format
- Path Sanitization - Removes quotes, validates paths, checks for null bytes
- Directory Auto-Creation - Creates output directories if they don't exist

#### Special Format Handling
- CMYK Color Space Warning - Alerts when CMYK images may not convert accurately
- Animated GIF Support - Uses first frame of animated GIFs with warning
- Transparency Support - Maintains transparent backgrounds in output

#### User Interface Features
- Quiet/Silent Mode - Suppresses console output except errors (-Quiet, -Silent, -q)
- Detailed Progress Messages - Shows input, output, size, and colors being used
- Color-Coded Output - Green for success, Cyan for special information
- File Size Reporting - Shows output file size in KB
- Built-in Help System - Complete documentation via -Help parameter
- Error Messages - Clear, specific error descriptions

#### Command-Line Interface
- Parameter Validation - ValidateRange for BorderWidth, ValidateSet for FaviconSize
- Parameter Aliases - Multiple ways to call parameters (e.g., -Base64 for -ReturnBase64)
- Pipeline Support - Returns output path or base64 string for pipeline usage
- Switch Parameters - Boolean flags for ReturnBase64, Help, Quiet

#### Output Options
- HTML Usage Examples - Shows how to use base64 output in HTML link tags
- Temporary File Handling - Uses temp files for base64 conversion without saving
- Return Value Flexibility - Returns file path or base64 string based on parameters

#### Error Handling & Recovery
- Comprehensive Try-Catch Blocks - Graceful error handling throughout
- Resource Cleanup - Properly disposes of graphics objects, images, and brushes
- Temp File Cleanup - Removes temporary files on error or after base64 conversion
- Assembly Loading Validation - Checks System.Drawing availability

#### Platform Features
- PowerShell 5.1+ Requirement - Ensures compatibility with required cmdlets
- Cross-User Downloads Detection - Finds Downloads folder regardless of user profile
- Fallback Directory Logic - Uses current directory if Downloads not found

#### Color Features
- Hex Color Support - Accepts standard #RRGGBB format
- HTML Color Translation - Converts hex codes to System.Drawing colors
- Color Array Support - Single color or array of colors for multiple rings

#### Advanced Graphics Settings
- HighQualityBicubic Interpolation - Best quality image scaling
- AntiAlias Smoothing - Smooth curves and edges
- HighQuality Compositing - Better color blending
- HighQuality Pixel Offset - Precise pixel rendering
- Center Pen Alignment - Borders drawn from center for accuracy

#### Usability Features
- No Input Required Mode - Works without any parameters (creates default orange circle)
- Smart Defaults - Sensible defaults for all optional parameters
- Warning System - Non-fatal warnings for CMYK, animated GIFs, missing Downloads folder
