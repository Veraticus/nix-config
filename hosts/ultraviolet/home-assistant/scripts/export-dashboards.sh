#!/usr/bin/env bash
# Export Home Assistant storage dashboards to YAML format

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paths
STORAGE_DIR="/var/lib/hass/.storage"
OUTPUT_DIR="$(dirname "$0")/../dashboards"

echo -e "${YELLOW}Home Assistant Dashboard Export Tool${NC}"
echo "====================================="
echo ""

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Function to export a dashboard
export_dashboard() {
    local storage_file="$1"
    local output_file="$2"
    local dashboard_name="$3"
    
    if [ ! -f "$STORAGE_DIR/$storage_file" ]; then
        echo -e "${RED}✗ $dashboard_name: Storage file not found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Exporting $dashboard_name...${NC}"
    
    # Export JSON and convert to YAML
    # Note: We need to extract just the config part, not the metadata
    sudo cat "$STORAGE_DIR/$storage_file" | \
        jq '.data.config' | \
        python3 -c "
import sys
import json
import yaml

# Custom representer for literal block style for long strings
def literal_presenter(dumper, data):
    if '\n' in data or len(data) > 80:
        return dumper.represent_scalar('tag:yaml.org,2002:str', data, style='|')
    return dumper.represent_scalar('tag:yaml.org,2002:str', data)

yaml.add_representer(str, literal_presenter)

# Load JSON from stdin
data = json.load(sys.stdin)

# Convert to YAML with nice formatting
print('# Home Assistant Dashboard - $dashboard_name')
print('# Exported from storage mode: $(date -Iseconds)')
print('# This file is now managed in Git')
print('')
yaml.dump(data, sys.stdout, 
          default_flow_style=False, 
          allow_unicode=True,
          width=120,
          sort_keys=False)
" > "$OUTPUT_DIR/$output_file"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Exported to $OUTPUT_DIR/$output_file${NC}"
        
        # Show file size and line count
        local size=$(wc -c < "$OUTPUT_DIR/$output_file" | xargs)
        local lines=$(wc -l < "$OUTPUT_DIR/$output_file" | xargs)
        echo "  Size: $(numfmt --to=iec-i --suffix=B $size), Lines: $lines"
    else
        echo -e "${RED}✗ Failed to export $dashboard_name${NC}"
        return 1
    fi
    echo ""
}

# Export each dashboard
echo "Exporting dashboards from storage mode..."
echo ""

export_dashboard "lovelace.bubble_overview" "bubble-overview.yaml" "Bubble Overview"
export_dashboard "lovelace.floor_plan_new" "floor-plan.yaml" "Floor Plan"

# Also create a simple map dashboard if needed
if [ -f "$STORAGE_DIR/lovelace.map" ]; then
    export_dashboard "lovelace.map" "map.yaml" "Map"
fi

echo -e "${GREEN}Dashboard export complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Review the exported YAML files in $OUTPUT_DIR"
echo "2. Update your NixOS configuration to use YAML mode"
echo "3. Run 'update' to apply the changes"
echo "4. Test the dashboards in Home Assistant"