#!/bin/bash
# Stateful Code Analyzer - Local Analysis Script
# Production-ready version with actual pattern detection
# Supports: .NET Framework, ASP.NET, Java/Spring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/stateful-analysis.json"
TEMP_FINDINGS="$SCRIPT_DIR/.findings_temp.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Stateful Code Analyzer v1.0                ║${NC}"
echo -e "${BLUE}║   Analyzing codebase for stateful patterns   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Detect project type
PROJECT_TYPE="unknown"
if [ -f *.csproj ] || [ -f *.sln ] || find . -maxdepth 3 -name "*.csproj" | grep -q .; then
    PROJECT_TYPE="dotnet"
    echo -e "${GREEN}✓ Detected .NET project${NC}"
elif [ -f pom.xml ] || [ -f build.gradle ]; then
    PROJECT_TYPE="java"
    echo -e "${GREEN}✓ Detected Java project${NC}"
else
    echo -e "${RED}✗ Could not detect project type${NC}"
    echo "Please ensure you're in the project root directory"
    exit 1
fi

# Initialize findings array
echo "[]" > "$TEMP_FINDINGS"

# Function to add finding to JSON
add_finding() {
    local file="$1"
    local function="$2"
    local line_num="$3"
    local code="$4"
    local category="$5"
    local severity="$6"
    
    # Escape quotes in code
    code=$(echo "$code" | sed 's/"/\\"/g')
    
    # Create finding JSON
    local finding=$(cat <<EOF
{
  "filename": "$file",
  "function": "$function",
  "lineNum": $line_num,
  "code": "$code",
  "category": "$category",
  "severity": "$severity"
}
EOF
)
    
    # Append to findings array
    local current=$(cat "$TEMP_FINDINGS")
    if [ "$current" = "[]" ]; then
        echo "[$finding]" > "$TEMP_FINDINGS"
    else
        echo "$current" | jq ". += [$finding]" > "$TEMP_FINDINGS.tmp"
        mv "$TEMP_FINDINGS.tmp" "$TEMP_FINDINGS"
    fi
}

# Function to extract method/function name
extract_function_name() {
    local file="$1"
    local line_num="$2"
    local start=$((line_num - 30))
    [ $start -lt 1 ] && start=1
    
    # Look backwards for method declaration
    awk -v start="$start" -v end="$line_num" '
        NR >= start && NR <= end {
            if (match($0, /(public|private|protected|internal).*\s+\w+\s*\(/)) {
                if (match($0, /\s+(\w+)\s*\(/, arr)) {
                    print arr[1]
                    exit
                }
            }
        }
        END { if (NR < end) print "Unknown" }
    ' "$file" | tail -1
}

# .NET specific patterns
analyze_dotnet() {
    echo -e "${YELLOW}Analyzing .NET code...${NC}"
    local total_files=0
    local issues_found=0
    
    # Find all C# files
    while IFS= read -r -d '' file; do
        ((total_files++))
        relative_file="${file#$SCRIPT_DIR/}"
        
        # Pattern 1: Session State
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "Session State" "high"
            ((issues_found++))
        done < <(grep -n 'Session\[' "$file" 2>/dev/null || true)
        
        # Pattern 2: Application State
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "Application State" "high"
            ((issues_found++))
        done < <(grep -n 'Application\[' "$file" 2>/dev/null || true)
        
        # Pattern 3: ViewState
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "ViewState" "medium"
            ((issues_found++))
        done < <(grep -n 'ViewState\[' "$file" 2>/dev/null || true)
        
        # Pattern 4: Static mutable fields
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            # Exclude readonly
            if ! echo "$code" | grep -q "readonly"; then
                function=$(extract_function_name "$file" "$line_num")
                add_finding "$relative_file" "$function" "$line_num" "$code" "Static Mutable Field" "high"
                ((issues_found++))
            fi
        done < <(grep -nE '(private|public)\s+static.*=' "$file" 2>/dev/null || true)
        
        # Pattern 5: MemoryCache
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "In-Process Cache" "medium"
            ((issues_found++))
        done < <(grep -nE '(MemoryCache\.Default|HttpRuntime\.Cache)' "$file" 2>/dev/null || true)
        
        echo -ne "\rScanned: $total_files files, Found: $issues_found issues"
        
    done < <(find . -type f -name "*.cs" \
        ! -path "*/bin/*" \
        ! -path "*/obj/*" \
        ! -path "*/packages/*" \
        ! -path "*/.vs/*" \
        -print0)
    
    echo ""
    echo -e "${GREEN}✓ .NET analysis complete${NC}"
    echo "  Files scanned: $total_files"
    echo "  Issues found: $issues_found"
}

# Java specific patterns
analyze_java() {
    echo -e "${YELLOW}Analyzing Java code...${NC}"
    local total_files=0
    local issues_found=0
    
    # Find all Java files
    while IFS= read -r -d '' file; do
        ((total_files++))
        relative_file="${file#$SCRIPT_DIR/}"
        
        # Pattern 1: HttpSession
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "Session State" "high"
            ((issues_found++))
        done < <(grep -nE '(\.getSession\(|session\.setAttribute)' "$file" 2>/dev/null || true)
        
        # Pattern 2: ServletContext
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "Application State" "high"
            ((issues_found++))
        done < <(grep -n 'getServletContext()\.setAttribute' "$file" 2>/dev/null || true)
        
        # Pattern 3: Static mutable fields
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            if ! echo "$code" | grep -q "final"; then
                function=$(extract_function_name "$file" "$line_num")
                add_finding "$relative_file" "$function" "$line_num" "$code" "Static Mutable Field" "high"
                ((issues_found++))
            fi
        done < <(grep -nE '(private|public)\s+static.*=' "$file" 2>/dev/null || true)
        
        # Pattern 4: ThreadLocal
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "Thread-Local Storage" "high"
            ((issues_found++))
        done < <(grep -n 'ThreadLocal' "$file" 2>/dev/null || true)
        
        # Pattern 5: Cache
        while IFS= read -r line_info; do
            line_num=$(echo "$line_info" | cut -d: -f1)
            code=$(echo "$line_info" | cut -d: -f2-)
            function=$(extract_function_name "$file" "$line_num")
            add_finding "$relative_file" "$function" "$line_num" "$code" "In-Process Cache" "medium"
            ((issues_found++))
        done < <(grep -nE '(CacheManager|EhCache|\.put\()' "$file" 2>/dev/null || true)
        
        echo -ne "\rScanned: $total_files files, Found: $issues_found issues"
        
    done < <(find . -type f -name "*.java" \
        ! -path "*/target/*" \
        ! -path "*/build/*" \
        ! -path "*/.idea/*" \
        -print0)
    
    echo ""
    echo -e "${GREEN}✓ Java analysis complete${NC}"
    echo "  Files scanned: $total_files"
    echo "  Issues found: $issues_found"
}

# Check for jq (required for JSON manipulation)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠ Installing jq for JSON processing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install -y jq || sudo yum install -y jq
    fi
fi

# Run appropriate analyzer
if [ "$PROJECT_TYPE" = "dotnet" ]; then
    analyze_dotnet
elif [ "$PROJECT_TYPE" = "java" ]; then
    analyze_java
fi

# Create final JSON output
cat > "$OUTPUT_FILE" <<EOF
{
  "projectType": "$PROJECT_TYPE",
  "scanDate": "$(date -Iseconds)",
  "rootPath": "$SCRIPT_DIR",
  "findings": $(cat "$TEMP_FINDINGS")
}
EOF

# Clean up temp file
rm -f "$TEMP_FINDINGS" "$TEMP_FINDINGS.tmp"

# Summary
TOTAL_ISSUES=$(jq '.findings | length' "$OUTPUT_FILE")

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Analysis Complete!                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✓ Output saved to: ${NC}$OUTPUT_FILE"
echo -e "${GREEN}✓ Total issues found: ${NC}$TOTAL_ISSUES"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the generated JSON file"
echo "  2. Upload to the web portal for detailed remediation suggestions"
echo "  3. Or send to API: curl -X POST -F 'jsonData=@$OUTPUT_FILE' https://api.your-domain.com/analyze"
echo ""