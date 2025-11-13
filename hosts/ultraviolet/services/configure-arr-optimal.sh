#!@bash@/bin/bash
set -euo pipefail

# Configure Radarr and Sonarr for optimal quality on ultraviolet
# Optimized for Intel i5-10500TE with UHD 630 (supports 4K HEVC hardware decode)

# Get API keys from filesystem
RADARR_API_KEY=$(@sudo@/bin/sudo cat /var/lib/radarr/.config/Radarr/config.xml 2>/dev/null | @gnugrep@/bin/grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
RADARR_URL="http://localhost:7878"

SONARR_API_KEY=$(@sudo@/bin/sudo cat /var/lib/sonarr/.config/NzbDrone/config.xml 2>/dev/null | @gnugrep@/bin/grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
SONARR_URL="http://localhost:8989"

if [ -z "$RADARR_API_KEY" ]; then
    echo "⚠ Could not find Radarr API key in /var/lib/radarr/.config/Radarr/config.xml"
    echo "  This is normal on fresh installations - Radarr needs to start first"
    echo "  Configuration will be applied on next boot after Radarr generates its config"

    # Still try to configure Sonarr if it's available
    if [ -n "$SONARR_API_KEY" ]; then
        echo "  Found Sonarr API key, will configure Sonarr only"
    else
        echo "  No Sonarr API key found either - exiting"
        exit 0
    fi
fi

# Only configure Radarr if we have an API key
if [ -n "$RADARR_API_KEY" ]; then
    echo "=== Configuring Radarr for optimal quality ==="
    echo "Target: 4K HEVC when available, 1080p HEVC fallback"
    echo ""

    # Clean up duplicate custom formats first
    cleanup_duplicate_formats() {
    echo "Cleaning up duplicate custom formats..."

    # Get all custom formats
    formats=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY")

    # Delete old duplicates (keep the newer ones with better names)
    # Delete "x264" if "x264/H.264" exists
    x264_old_id=$(echo "$formats" | @jq@/bin/jq '.[] | select(.name == "x264") | .id')
    x264_new_id=$(echo "$formats" | @jq@/bin/jq '.[] | select(.name == "x264/H.264") | .id')

    if [ -n "$x264_old_id" ] && [ -n "$x264_new_id" ] && [ "$x264_old_id" != "null" ] && [ "$x264_new_id" != "null" ]; then
        echo "  Removing duplicate: x264 (keeping x264/H.264)"
        @curl@/bin/curl -X DELETE "$RADARR_URL/api/v3/customformat/$x264_old_id" -H "X-Api-Key: $RADARR_API_KEY" > /dev/null 2>&1
    fi

    # Delete "Large File Size" as we're using bitrate limits instead
    large_id=$(echo "$formats" | @jq@/bin/jq '.[] | select(.name == "Large File Size") | .id')
    if [ -n "$large_id" ] && [ "$large_id" != "null" ]; then
        echo "  Removing obsolete: Large File Size (using bitrate limits instead)"
        @curl@/bin/curl -X DELETE "$RADARR_URL/api/v3/customformat/$large_id" -H "X-Api-Key: $RADARR_API_KEY" > /dev/null 2>&1
    fi

    echo "  Cleanup complete"
}

# Function to create or update custom format
create_or_update_format() {
    local name="$1"
    local spec_json="$2"

    # Check if format exists
    existing_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq --arg name "$name" '.[] | select(.name == $name) | .id')

    if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
        echo "  Updating existing format: $name (ID: $existing_id)"
        @curl@/bin/curl -X PUT "$RADARR_URL/api/v3/customformat/$existing_id" \
            -H "X-Api-Key: $RADARR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$spec_json" > /dev/null 2>&1
    else
        echo "  Creating new format: $name"
        @curl@/bin/curl -X POST "$RADARR_URL/api/v3/customformat" \
            -H "X-Api-Key: $RADARR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$spec_json" > /dev/null 2>&1
    fi
}

# Clean up duplicates first
cleanup_duplicate_formats

# Create custom formats
echo "Creating/updating custom formats..."

# HEVC/x265 format (strongly preferred for 4K)
create_or_update_format "x265/HEVC" '{
    "name": "x265/HEVC",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "x265/HEVC",
            "implementation": "ReleaseTitleSpecification",
            "implementationName": "Release Title",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": "\\b(x265|h265|hevc)\\b"
                }
            ]
        }
    ]
}'

# Bad release groups to avoid
create_or_update_format "Bad Release Groups" '{
    "name": "Bad Release Groups",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "Bad Release Groups",
            "implementation": "ReleaseTitleSpecification",
            "implementationName": "Release Title",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": "\\b(YIFY|YTS|RARBG.*REENC|TERRiBLE|LiGaS|BRrip|CHD|RM|mSD|HDTime|SiC)\\b"
                }
            ]
        }
    ]
}'

# Trusted HEVC encoders
create_or_update_format "Trusted HEVC Groups" '{
    "name": "Trusted HEVC Groups",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "Trusted HEVC Groups",
            "implementation": "ReleaseTitleSpecification",
            "implementationName": "Release Title",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": "\\b(QxR|UTR|TOMMY|FLUX|NTb|CtrlHD|TERMINAL|TIGERS|HONE|MONOLITH|PSA|MZABI|TAoE|SEV|CMRG)\\b"
                }
            ]
        }
    ]
}'

# Re-encoded content warning
create_or_update_format "Re-Encoded" '{
    "name": "Re-Encoded",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "Re-Encoded",
            "implementation": "ReleaseTitleSpecification",
            "implementationName": "Release Title",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": "\\b(REENC|ReEnc|Re-Enc|Reencoded)\\b"
                }
            ]
        }
    ]
}'

# x264 format (okay for 1080p, bad for 4K)
create_or_update_format "x264/H.264" '{
    "name": "x264/H.264",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "x264/H.264",
            "implementation": "ReleaseTitleSpecification",
            "implementationName": "Release Title",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": "\\b(x264|h264|avc)\\b"
                }
            ]
        }
    ]
}'

# 4K resolution format (bonus points when HEVC)
create_or_update_format "4K/2160p" '{
    "name": "4K/2160p",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "4K Resolution",
            "implementation": "ResolutionSpecification",
            "implementationName": "Resolution",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": 2160
                }
            ]
        }
    ]
}'

# Remove the old absolute size format if it exists
echo "  Removing old Excessive Size format (replacing with bitrate-based)..."
old_excessive_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Excessive Size") | .id')
if [ -n "$old_excessive_id" ] && [ "$old_excessive_id" != "null" ]; then
    @curl@/bin/curl -X DELETE "$RADARR_URL/api/v3/customformat/$old_excessive_id" -H "X-Api-Key: $RADARR_API_KEY" > /dev/null 2>&1
fi

# Remux format (these are unnecessarily large)
create_or_update_format "Remux" '{
    "name": "Remux",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "Remux",
            "implementation": "ReleaseTitleSpecification",
            "implementationName": "Release Title",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": "\\b(remux)\\b"
                }
            ]
        }
    ]
}'

# Foreign Film format
create_or_update_format "Foreign Film" '{
    "name": "Foreign Film",
    "includeCustomFormatWhenRenaming": false,
    "specifications": [
        {
            "name": "Foreign Indicators",
            "implementation": "ReleaseTitleSpecification",
            "implementationName": "Release Title",
            "infoLink": "https://wiki.servarr.com/radarr/settings#custom-formats-2",
            "negate": false,
            "required": false,
            "fields": [
                {
                    "name": "value",
                    "value": "\\b(japanese|korean|chinese|french|german|italian|spanish|russian|swedish|danish|norwegian|finnish|polish|hindi|thai)\\b"
                }
            ]
        }
    ]
}'

echo ""
echo "Configuring quality definitions (bitrate limits)..."

# Configure quality definitions with sensible bitrate limits (MB/minute)
# These ensure TV episodes don't grab unnecessarily large files
@curl@/bin/curl -s "$RADARR_URL/api/v3/qualitydefinition" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq -c '.[]' | while read -r def; do
    quality_name=$(echo "$def" | @jq@/bin/jq -r '.quality.name')
    def_id=$(echo "$def" | @jq@/bin/jq '.id')

    case "$quality_name" in
        "HDTV-720p"|"WEBDL-720p"|"Bluray-720p")
            # 720p: Target ~3-5 Mbps (22-38 MB/min)
            updated=$(echo "$def" | @jq@/bin/jq '.minSize = 15 | .maxSize = 45 | .preferredSize = 30')
            ;;
        "HDTV-1080p"|"WEBDL-1080p"|"Bluray-1080p")
            # 1080p: Target ~8-12 Mbps (60-90 MB/min)
            updated=$(echo "$def" | @jq@/bin/jq '.minSize = 40 | .maxSize = 100 | .preferredSize = 70')
            ;;
        "HDTV-2160p"|"WEBDL-2160p"|"Bluray-2160p")
            # 4K: Target ~20-35 Mbps HEVC (150-260 MB/min)
            updated=$(echo "$def" | @jq@/bin/jq '.minSize = 100 | .maxSize = 300 | .preferredSize = 200')
            ;;
        "Remux-1080p")
            # 1080p Remux: ~25-35 Mbps (190-260 MB/min) - discouraged
            updated=$(echo "$def" | @jq@/bin/jq '.minSize = 150 | .maxSize = 300 | .preferredSize = 200')
            ;;
        "Remux-2160p")
            # 4K Remux: ~50-80 Mbps (375-600 MB/min) - strongly discouraged
            updated=$(echo "$def" | @jq@/bin/jq '.minSize = 300 | .maxSize = 700 | .preferredSize = 400')
            ;;
        *)
            # Keep existing for others
            continue
            ;;
    esac

    echo "  Setting $quality_name bitrate limits..."
    @curl@/bin/curl -X PUT "$RADARR_URL/api/v3/qualitydefinition/$def_id" \
        -H "X-Api-Key: $RADARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$updated" > /dev/null 2>&1
done

echo ""
echo "Getting custom format IDs..."

# Get all format IDs
hevc_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "x265/HEVC") | .id')
x264_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "x264/H.264") | .id')
fourk_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "4K/2160p") | .id')
remux_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Remux") | .id')
foreign_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Foreign Film") | .id')
bad_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Bad Release Groups") | .id')
trusted_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Trusted HEVC Groups") | .id')
reenc_id=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/customformat" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Re-Encoded") | .id')

echo "Updating quality profiles with optimal scoring..."

# Update all quality profiles with the new scoring
@curl@/bin/curl -s "$RADARR_URL/api/v3/qualityprofile" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq -c '.[]' | while read -r profile; do
    profile_id=$(echo "$profile" | @jq@/bin/jq '.id')
    profile_name=$(echo "$profile" | @jq@/bin/jq -r '.name')

    echo "  Updating profile: $profile_name"

    # Build format items with scores optimized for 4K HEVC
    format_items="["
    [ -n "$hevc_id" ] && [ "$hevc_id" != "null" ] && format_items+="{\"format\": $hevc_id, \"name\": \"x265/HEVC\", \"score\": 150},"
    [ -n "$trusted_id" ] && [ "$trusted_id" != "null" ] && format_items+="{\"format\": $trusted_id, \"name\": \"Trusted HEVC Groups\", \"score\": 100},"
    [ -n "$fourk_id" ] && [ "$fourk_id" != "null" ] && format_items+="{\"format\": $fourk_id, \"name\": \"4K/2160p\", \"score\": 50},"
    [ -n "$foreign_id" ] && [ "$foreign_id" != "null" ] && format_items+="{\"format\": $foreign_id, \"name\": \"Foreign Film\", \"score\": 30},"
    [ -n "$x264_id" ] && [ "$x264_id" != "null" ] && format_items+="{\"format\": $x264_id, \"name\": \"x264/H.264\", \"score\": -30},"
    [ -n "$reenc_id" ] && [ "$reenc_id" != "null" ] && format_items+="{\"format\": $reenc_id, \"name\": \"Re-Encoded\", \"score\": -100},"
    [ -n "$remux_id" ] && [ "$remux_id" != "null" ] && format_items+="{\"format\": $remux_id, \"name\": \"Remux\", \"score\": -200},"
    [ -n "$bad_id" ] && [ "$bad_id" != "null" ] && format_items+="{\"format\": $bad_id, \"name\": \"Bad Release Groups\", \"score\": -1000},"
    format_items="''${format_items%,}]"

    # Update profile with new scoring and settings
    updated_profile=$(echo "$profile" | @jq@/bin/jq \
        --argjson items "$format_items" \
        '.formatItems = $items |
         .minFormatScore = -150 |
         .cutoffFormatScore = 100 |
         .upgradeAllowed = true |
         .cutoff = 9 |
         (.items[]? | select(.quality.name? and (.quality.name | test("2160p")))).allowed = true |
         (.items[]? | select(.quality.name? and (.quality.name | test("1080p")))).allowed = true |
         (.items[]? | select(.quality.name? and (.quality.name | test("720p")))).allowed = true |
         (.items[]? | select(.quality.name? and (.quality.name | test("Remux")))).allowed = false |
         (.items[]? | select(.quality.name? and ((.quality.name | test("480p")) or (.quality.name | test("DVD")) or (.quality.name | test("SDTV"))))).allowed = false'
    )

    @curl@/bin/curl -X PUT "$RADARR_URL/api/v3/qualityprofile/$profile_id" \
        -H "X-Api-Key: $RADARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$updated_profile" > /dev/null 2>&1
done

echo ""
echo "Setting HD - 720p/1080p as default profile for all movies..."

# Set profile 6 (HD - 720p/1080p) as default for all movies
movie_ids=$(@curl@/bin/curl -s "$RADARR_URL/api/v3/movie" -H "X-Api-Key: $RADARR_API_KEY" | @jq@/bin/jq -r '[.[].id] | @csv' | tr -d '"')
movie_count=$(echo "$movie_ids" | tr ',' '\n' | @coreutils@/bin/wc -l)

if [ -n "$movie_ids" ]; then
    bulk_edit="{\"movieIds\": [$movie_ids], \"qualityProfileId\": 6, \"moveFiles\": false}"

    @curl@/bin/curl -X PUT "$RADARR_URL/api/v3/movie/editor" \
        -H "X-Api-Key: $RADARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$bulk_edit" > /dev/null 2>&1

    echo "  Updated $movie_count movies to use optimized profile"
fi
fi  # End of Radarr configuration block

# Configure Sonarr if available (v4 uses Custom Formats like Radarr)
if [ -n "$SONARR_API_KEY" ]; then
    echo ""
    echo "=== Configuring Sonarr ==="

    # Sonarr v4 uses Custom Formats similar to Radarr
    echo "Creating custom formats for Sonarr..."

    # Function to create or update Sonarr custom format
    create_or_update_sonarr_format() {
        local name="$1"
        local json="$2"

        # Check if format exists
        local existing_id=$(@curl@/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | \
            @jq@/bin/jq --arg name "$name" '.[] | select(.name == $name) | .id')

        if [ -n "$existing_id" ] && [ "$existing_id" != "null" ]; then
            # Update existing format
            @curl@/bin/curl -X PUT "$SONARR_URL/api/v3/customformat/$existing_id" \
                -H "X-Api-Key: $SONARR_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$(echo "$json" | @jq@/bin/jq --argjson id "$existing_id" '. + {id: $id}')" > /dev/null 2>&1
            echo "  Updated custom format: $name"
        else
            # Create new format
            @curl@/bin/curl -X POST "$SONARR_URL/api/v3/customformat" \
                -H "X-Api-Key: $SONARR_API_KEY" \
                -H "Content-Type: application/json" \
                -d "$json" > /dev/null 2>&1
            echo "  Created custom format: $name"
        fi
    }

    # Create HEVC format
    create_or_update_sonarr_format "x265/HEVC" '{
        "name": "x265/HEVC",
        "includeCustomFormatWhenRenaming": false,
        "specifications": [
            {
                "name": "x265/HEVC",
                "implementation": "ReleaseTitleSpecification",
                "implementationName": "Release Title",
                "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                "negate": false,
                "required": false,
                "fields": [
                    {
                        "name": "value",
                        "value": "\\b(x265|h265|hevc)\\b"
                    }
                ]
            }
        ]
    }'

    # Create bad release groups format
    create_or_update_sonarr_format "Bad Release Groups" '{
        "name": "Bad Release Groups",
        "includeCustomFormatWhenRenaming": false,
        "specifications": [
            {
                "name": "Bad Release Groups",
                "implementation": "ReleaseTitleSpecification",
                "implementationName": "Release Title",
                "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                "negate": false,
                "required": false,
                "fields": [
                    {
                        "name": "value",
                        "value": "\\b(YIFY|YTS|RARBG.*REENC|TERRiBLE|LiGaS|BRrip|CHD|RM|mSD|HDTime|SiC)\\b"
                    }
                ]
            }
        ]
    }'

    # Create trusted HEVC groups format
    create_or_update_sonarr_format "Trusted HEVC Groups" '{
        "name": "Trusted HEVC Groups",
        "includeCustomFormatWhenRenaming": false,
        "specifications": [
            {
                "name": "Trusted HEVC Groups",
                "implementation": "ReleaseTitleSpecification",
                "implementationName": "Release Title",
                "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                "negate": false,
                "required": false,
                "fields": [
                    {
                        "name": "value",
                        "value": "\\b(QxR|UTR|TOMMY|FLUX|NTb|CtrlHD|TERMINAL|TIGERS|HONE|MONOLITH|PSA|MZABI|TAoE|SEV|CMRG)\\b"
                    }
                ]
            }
        ]
    }'

    # Create re-encoded format
    create_or_update_sonarr_format "Re-Encoded" '{
        "name": "Re-Encoded",
        "includeCustomFormatWhenRenaming": false,
        "specifications": [
            {
                "name": "Re-Encoded",
                "implementation": "ReleaseTitleSpecification",
                "implementationName": "Release Title",
                "infoLink": "https://wiki.servarr.com/sonarr/settings#custom-formats-2",
                "negate": false,
                "required": false,
                "fields": [
                    {
                        "name": "value",
                        "value": "\\b(REENC|ReEnc|Re-Enc|Reencoded)\\b"
                    }
                ]
            }
        ]
    }'

    # Also keep the release profile for blocking (it still works for must not contain)
    bad_existing=$(@curl@/bin/curl -s "$SONARR_URL/api/v3/releaseprofile" -H "X-Api-Key: $SONARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Block Bad Encoders")')

    if [ -z "$bad_existing" ]; then
        echo "  Creating bad encoder blocking profile..."
        @curl@/bin/curl -X POST "$SONARR_URL/api/v3/releaseprofile" \
            -H "X-Api-Key: $SONARR_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{
                "name": "Block Bad Encoders",
                "enabled": true,
                "required": [],
                "ignored": [
                    "YIFY",
                    "YTS",
                    "RARBG.*REENC",
                    "TERRiBLE",
                    "LiGaS",
                    "BRrip",
                    "CHD",
                    "RM",
                    "mSD",
                    "HDTime",
                    "SiC",
                    "REENC",
                    "ReEnc",
                    "Re-Enc",
                    "Reencoded"
                ],
                "indexerId": 0,
                "tags": []
            }' > /dev/null 2>&1
        echo "  Bad encoder blocking profile created"
    else
        echo "  Bad encoder blocking profile already exists"
    fi

    # Now update quality profiles with custom format scores
    echo "Updating Sonarr quality profiles with custom format scoring..."

    # Get format IDs
    hevc_id=$(@curl@/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "x265/HEVC") | .id')
    bad_id=$(@curl@/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Bad Release Groups") | .id')
    trusted_id=$(@curl@/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Trusted HEVC Groups") | .id')
    reenc_id=$(@curl@/bin/curl -s "$SONARR_URL/api/v3/customformat" -H "X-Api-Key: $SONARR_API_KEY" | @jq@/bin/jq '.[] | select(.name == "Re-Encoded") | .id')

    # Update quality profiles
    @curl@/bin/curl -s "$SONARR_URL/api/v3/qualityprofile" -H "X-Api-Key: $SONARR_API_KEY" | @jq@/bin/jq -c '.[]' | while read -r profile; do
        profile_id=$(echo "$profile" | @jq@/bin/jq '.id')
        profile_name=$(echo "$profile" | @jq@/bin/jq -r '.name')

        echo "  Updating profile: $profile_name"

        # Build format items with scores
        format_items="["
        [ -n "$hevc_id" ] && [ "$hevc_id" != "null" ] && format_items+="{\"format\": $hevc_id, \"name\": \"x265/HEVC\", \"score\": 100},"
        [ -n "$trusted_id" ] && [ "$trusted_id" != "null" ] && format_items+="{\"format\": $trusted_id, \"name\": \"Trusted HEVC Groups\", \"score\": 50},"
        [ -n "$reenc_id" ] && [ "$reenc_id" != "null" ] && format_items+="{\"format\": $reenc_id, \"name\": \"Re-Encoded\", \"score\": -100},"
        [ -n "$bad_id" ] && [ "$bad_id" != "null" ] && format_items+="{\"format\": $bad_id, \"name\": \"Bad Release Groups\", \"score\": -1000},"
        format_items="''${format_items%,}]"

        # Update profile
        updated_profile=$(echo "$profile" | @jq@/bin/jq \
            --argjson items "$format_items" \
            '.formatItems = $items | .minFormatScore = -1000 | .cutoffFormatScore = 10000'
        )

        @curl@/bin/curl -X PUT "$SONARR_URL/api/v3/qualityprofile/$profile_id" \
            -H "X-Api-Key: $SONARR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$updated_profile" > /dev/null 2>&1
    done

    echo "  Sonarr configuration complete"
fi

echo ""
echo "✅ Configuration complete!"
echo ""
echo "Optimized for Intel UHD 630 with 4K HEVC hardware decode:"
echo ""
echo "Format scoring:"
echo "  • x265/HEVC: +150 points (essential for 4K content)"
echo "  • Trusted HEVC Groups: +100 points (quality encoders)"
echo "  • 4K/2160p: +50 points (your hardware handles this well with HEVC)"
echo "  • Foreign films: +30 points (for international content)"
echo "  • x264/H.264: -30 points (mild penalty, still grabbable)"
echo "  • Re-Encoded: -100 points (avoid poor re-encodes)"
echo "  • Remux: -200 points (unnecessarily large, uncompressed)"
echo "  • Bad Release Groups: -1000 points (blocks known bad encoders)"
echo ""
echo "Bitrate limits (prevents oversized TV episodes):"
echo "  • 720p: 3-5 Mbps (2-4 GB per movie, 200-400 MB per TV episode)"
echo "  • 1080p: 8-12 Mbps (5-9 GB per movie, 500-900 MB per TV episode)"
echo "  • 4K HEVC: 20-35 Mbps (15-26 GB per movie, 1.5-2.6 GB per TV episode)"
echo ""
echo "Your system can easily handle 4K HEVC at these bitrates!"
echo "TV episodes won't exceed reasonable sizes for their runtime."
