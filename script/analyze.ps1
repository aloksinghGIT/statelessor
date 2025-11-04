# Stateful Code Analyzer - Local Analysis Script (PowerShell)
# Production-ready version with actual pattern detection
# Supports: .NET Framework, ASP.NET, Java/Spring

param(
    [string]$OutputPath = $null
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputFile = if ($OutputPath) { $OutputPath } else { Join-Path $ScriptDir "stateful-analysis.json" }
$TempFindings = Join-Path $ScriptDir ".findings_temp.json"

Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║   Stateful Code Analyzer v1.0                ║" -ForegroundColor Blue
Write-Host "║   Analyzing codebase for stateful patterns   ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host ""

# Detect project type
$ProjectType = "unknown"
if ((Test-Path "*.csproj") -or (Test-Path "*.sln") -or (Get-ChildItem -Recurse -Filter "*.csproj" -Depth 3)) {
    $ProjectType = "dotnet"
    Write-Host "✓ Detected .NET project" -ForegroundColor Green
} elseif ((Test-Path "pom.xml") -or (Test-Path "build.gradle")) {
    $ProjectType = "java"
    Write-Host "✓ Detected Java project" -ForegroundColor Green
} else {
    Write-Host "✗ Could not detect project type" -ForegroundColor Red
    Write-Host "Please ensure you're in the project root directory"
    exit 1
}

# Initialize findings array
@() | ConvertTo-Json | Out-File -FilePath $TempFindings -Encoding UTF8

# Function to add finding to JSON
function Add-Finding {
    param(
        [string]$File,
        [string]$Function,
        [int]$LineNum,
        [string]$Code,
        [string]$Category,
        [string]$Severity
    )
    
    $finding = @{
        filename = $File
        function = $Function
        lineNum = $LineNum
        code = $Code
        category = $Category
        severity = $Severity
    }
    
    $current = Get-Content $TempFindings | ConvertFrom-Json
    $current += $finding
    $current | ConvertTo-Json -Depth 10 | Out-File -FilePath $TempFindings -Encoding UTF8
}

# Function to extract method/function name
function Get-FunctionName {
    param(
        [string]$FilePath,
        [int]$LineNum
    )
    
    $start = [Math]::Max(1, $LineNum - 30)
    $lines = Get-Content $FilePath
    
    for ($i = $LineNum - 1; $i -ge $start - 1; $i--) {
        if ($lines[$i] -match '(public|private|protected|internal).*\s+(\w+)\s*\(') {
            return $matches[2]
        }
    }
    return "Unknown"
}

# .NET specific patterns
function Analyze-DotNet {
    Write-Host "Analyzing .NET code..." -ForegroundColor Yellow
    $totalFiles = 0
    $issuesFound = 0
    
    $csFiles = Get-ChildItem -Recurse -Filter "*.cs" | Where-Object {
        $_.FullName -notmatch '\\(bin|obj|packages|\\.vs)\\' 
    }
    
    foreach ($file in $csFiles) {
        $totalFiles++
        $relativeFile = $file.FullName.Replace("$ScriptDir\", "")
        $content = Get-Content $file.FullName
        
        # Pattern 1: Session State
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match 'Session\[') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "Session State" "high"
                $issuesFound++
            }
        }
        
        # Pattern 2: Application State
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match 'Application\[') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "Application State" "high"
                $issuesFound++
            }
        }
        
        # Pattern 3: ViewState
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match 'ViewState\[') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "ViewState" "medium"
                $issuesFound++
            }
        }
        
        # Pattern 4: Static mutable fields
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match '(private|public)\s+static.*=' -and $content[$i] -notmatch 'readonly') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "Static Mutable Field" "high"
                $issuesFound++
            }
        }
        
        # Pattern 5: MemoryCache
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match '(MemoryCache\.Default|HttpRuntime\.Cache)') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "In-Process Cache" "medium"
                $issuesFound++
            }
        }
        
        Write-Progress -Activity "Scanning .NET files" -Status "Scanned: $totalFiles files, Found: $issuesFound issues" -PercentComplete (($totalFiles / $csFiles.Count) * 100)
    }
    
    Write-Host ""
    Write-Host "✓ .NET analysis complete" -ForegroundColor Green
    Write-Host "  Files scanned: $totalFiles"
    Write-Host "  Issues found: $issuesFound"
}

# Java specific patterns
function Analyze-Java {
    Write-Host "Analyzing Java code..." -ForegroundColor Yellow
    $totalFiles = 0
    $issuesFound = 0
    
    $javaFiles = Get-ChildItem -Recurse -Filter "*.java" | Where-Object {
        $_.FullName -notmatch '\\(target|build|\\.idea)\\' 
    }
    
    foreach ($file in $javaFiles) {
        $totalFiles++
        $relativeFile = $file.FullName.Replace("$ScriptDir\", "")
        $content = Get-Content $file.FullName
        
        # Pattern 1: HttpSession
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match '(\.getSession\(|session\.setAttribute)') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "Session State" "high"
                $issuesFound++
            }
        }
        
        # Pattern 2: ServletContext
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match 'getServletContext\(\)\.setAttribute') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "Application State" "high"
                $issuesFound++
            }
        }
        
        # Pattern 3: Static mutable fields
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match '(private|public)\s+static.*=' -and $content[$i] -notmatch 'final') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "Static Mutable Field" "high"
                $issuesFound++
            }
        }
        
        # Pattern 4: ThreadLocal
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match 'ThreadLocal') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "Thread-Local Storage" "high"
                $issuesFound++
            }
        }
        
        # Pattern 5: Cache
        for ($i = 0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match '(CacheManager|EhCache|\.put\()') {
                $function = Get-FunctionName $file.FullName ($i + 1)
                Add-Finding $relativeFile $function ($i + 1) $content[$i].Trim() "In-Process Cache" "medium"
                $issuesFound++
            }
        }
        
        Write-Progress -Activity "Scanning Java files" -Status "Scanned: $totalFiles files, Found: $issuesFound issues" -PercentComplete (($totalFiles / $javaFiles.Count) * 100)
    }
    
    Write-Host ""
    Write-Host "✓ Java analysis complete" -ForegroundColor Green
    Write-Host "  Files scanned: $totalFiles"
    Write-Host "  Issues found: $issuesFound"
}

# Run appropriate analyzer
if ($ProjectType -eq "dotnet") {
    Analyze-DotNet
} elseif ($ProjectType -eq "java") {
    Analyze-Java
}

# Create final JSON output
$findings = Get-Content $TempFindings | ConvertFrom-Json
$analysis = @{
    projectType = $ProjectType
    scanDate = (Get-Date -Format o)
    rootPath = $ScriptDir
    findings = $findings
}

$analysis | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8

# Clean up temp file
Remove-Item $TempFindings -ErrorAction SilentlyContinue

# Summary
$totalIssues = $findings.Count

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Blue
Write-Host "║           Analysis Complete!                  ║" -ForegroundColor Blue
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Blue
Write-Host "✓ Output saved to: $OutputFile" -ForegroundColor Green
Write-Host "✓ Total issues found: $totalIssues" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review the generated JSON file"
Write-Host "  2. Upload to the web portal for detailed remediation suggestions"
Write-Host "  3. Or send to API: Invoke-RestMethod -Uri 'https://api.your-domain.com/analyze' -Method Post -InFile '$OutputFile'"
Write-Host ""