#!@bash@/bin/bash
set -euo pipefail

# Configure Radarr and Sonarr for optimal quality on ultraviolet
# Optimized for Intel i5-10500TE with UHD 630 (supports 4K HEVC hardware decode)

# Get API keys from filesystem
RADARR_API_KEY=$(@sudo@/bin/sudo cat /var/lib/radarr/.config/Radarr/config.xml 2>/dev/null | @gnugrep@/bin/grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
RADARR_URL="http://localhost:7878"

SONARR_API_KEY=$(@sudo@/bin/sudo cat /var/lib/sonarr/.config/NzbDrone/config.xml 2>/dev/null | @gnugrep@/bin/grep -oP '(?<=<ApiKey>)[^<]+' || echo "")
SONARR_URL="http://localhost:8989"

radarr_api() {
    local method="$1"
    local path="$2"
    shift 2
    local data="${1-}"

    local -a curl_args=(
        "@curl@/bin/curl"
        "-fsS"
        "-X" "$method"
        "$RADARR_URL$path"
        "-H" "X-Api-Key: $RADARR_API_KEY"
    )

    if [ $# -ge 1 ]; then
        curl_args+=("-H" "Content-Type: application/json" "-d" "$data")
    fi

    "${curl_args[@]}"
}

sonarr_api() {
    local method="$1"
    local path="$2"
    shift 2
    local data="${1-}"

    local -a curl_args=(
        "@curl@/bin/curl"
        "-fsS"
        "-X" "$method"
        "$SONARR_URL$path"
        "-H" "X-Api-Key: $SONARR_API_KEY"
    )

    if [ $# -ge 1 ]; then
        curl_args+=("-H" "Content-Type: application/json" "-d" "$data")
    fi

    "${curl_args[@]}"
}

RADARR_FORMAT_CACHE=""
SONARR_FORMAT_CACHE=""

radarr_invalidate_formats() {
    RADARR_FORMAT_CACHE=""
}

sonarr_invalidate_formats() {
    SONARR_FORMAT_CACHE=""
}

radarr_formats() {
    if [ -z "${RADARR_FORMAT_CACHE:-}" ]; then
        RADARR_FORMAT_CACHE=$(radarr_api GET "/api/v3/customformat")
    fi

    printf '%s' "$RADARR_FORMAT_CACHE"
}

sonarr_formats() {
    if [ -z "${SONARR_FORMAT_CACHE:-}" ]; then
        SONARR_FORMAT_CACHE=$(sonarr_api GET "/api/v3/customformat")
    fi

    printf '%s' "$SONARR_FORMAT_CACHE"
}

radarr_get_format_id() {
    local name="$1"
    radarr_formats | @jq@/bin/jq --arg name "$name" -r '.[] | select(.name == $name) | .id' | head -n1
}

sonarr_get_format_id() {
    local name="$1"
    sonarr_formats | @jq@/bin/jq --arg name "$name" -r '.[] | select(.name == $name) | .id' | head -n1
}

radarr_sync_format() {
    local name="$1"
    local payload="$2"
    local existing_id
    existing_id=$(radarr_get_format_id "$name" || true)

    if [ -n "${existing_id:-}" ]; then
        echo "  Updating existing format: $name (ID: $existing_id)"
        radarr_api PUT "/api/v3/customformat/$existing_id" "$payload" > /dev/null
    else
        echo "  Creating new format: $name"
        radarr_api POST "/api/v3/customformat" "$payload" > /dev/null
    fi

    radarr_invalidate_formats
}

sonarr_sync_format() {
    local name="$1"
    local payload="$2"
    local existing_id
    existing_id=$(sonarr_get_format_id "$name" || true)

    if [ -n "${existing_id:-}" ]; then
        echo "  Updating custom format: $name (ID: $existing_id)"
        sonarr_api PUT "/api/v3/customformat/$existing_id" "$payload" > /dev/null
    else
        echo "  Creating custom format: $name"
        sonarr_api POST "/api/v3/customformat" "$payload" > /dev/null
    fi

    sonarr_invalidate_formats
}

radarr_delete_format() {
    local name="$1"
    local format_id
    format_id=$(radarr_get_format_id "$name" || true)

    if [ -n "${format_id:-}" ]; then
        echo "  Removing obsolete format: $name"
        radarr_api DELETE "/api/v3/customformat/$format_id" > /dev/null
        radarr_invalidate_formats
    fi
}

cleanup_duplicate_formats() {
    echo "Cleaning up duplicate custom formats..."

    local x264_old_id
    local x264_new_id
    x264_old_id=$(radarr_get_format_id "x264" || true)
    x264_new_id=$(radarr_get_format_id "x264/H.264" || true)

    if [ -n "${x264_old_id:-}" ] && [ -n "${x264_new_id:-}" ]; then
        echo "  Removing duplicate: x264 (keeping x264/H.264)"
        radarr_api DELETE "/api/v3/customformat/$x264_old_id" > /dev/null
        radarr_invalidate_formats
    fi

    radarr_delete_format "Large File Size"
    echo "  Cleanup complete"
}

configure_radarr_quality_definitions() {
    echo ""
    echo "Configuring quality definitions (bitrate limits)..."

    local definitions
    definitions=$(radarr_api GET "/api/v3/qualitydefinition")

    echo "$definitions" | @jq@/bin/jq -c '.[]' | while read -r def; do
        local quality_name
        quality_name=$(@jq@/bin/jq -r '.quality.name' <<< "$def")
        local def_id
        def_id=$(@jq@/bin/jq '.id' <<< "$def")
        local updated

        case "$quality_name" in
            "HDTV-720p"|"WEBDL-720p"|"Bluray-720p")
                updated=$(@jq@/bin/jq '.minSize = 15 | .maxSize = 45 | .preferredSize = 30' <<< "$def")
                ;;
            "HDTV-1080p"|"WEBDL-1080p"|"Bluray-1080p")
                updated=$(@jq@/bin/jq '.minSize = 40 | .maxSize = 100 | .preferredSize = 70' <<< "$def")
                ;;
            "HDTV-2160p"|"WEBDL-2160p"|"Bluray-2160p")
                updated=$(@jq@/bin/jq '.minSize = 100 | .maxSize = 300 | .preferredSize = 200' <<< "$def")
                ;;
            "Remux-1080p")
                updated=$(@jq@/bin/jq '.minSize = 150 | .maxSize = 300 | .preferredSize = 200' <<< "$def")
                ;;
            "Remux-2160p")
                updated=$(@jq@/bin/jq '.minSize = 300 | .maxSize = 700 | .preferredSize = 400' <<< "$def")
                ;;
            *)
                continue
                ;;
        esac

        echo "  Setting $quality_name bitrate limits..."
        radarr_api PUT "/api/v3/qualitydefinition/$def_id" "$updated" > /dev/null
    done
}

build_radarr_format_map() {
    @jq@/bin/jq -c 'map({key: .name, value: .id}) | from_entries' <<< "$(radarr_formats)"
}

build_radarr_format_items() {
    local format_map_json="$1"
    @jq@/bin/jq -cn --argjson formats "$format_map_json" '[
        (if $formats["x265/HEVC"]? then {format: $formats["x265/HEVC"], name: "x265/HEVC", score: 150} else empty end),
        (if $formats["Trusted HEVC Groups"]? then {format: $formats["Trusted HEVC Groups"], name: "Trusted HEVC Groups", score: 100} else empty end),
        (if $formats["4K/2160p"]? then {format: $formats["4K/2160p"], name: "4K/2160p", score: 50} else empty end),
        (if $formats["Foreign Film"]? then {format: $formats["Foreign Film"], name: "Foreign Film", score: 30} else empty end),
        (if $formats["x264/H.264"]? then {format: $formats["x264/H.264"], name: "x264/H.264", score: -30} else empty end),
        (if $formats["Re-Encoded"]? then {format: $formats["Re-Encoded"], name: "Re-Encoded", score: -100} else empty end),
        (if $formats["Remux"]? then {format: $formats["Remux"], name: "Remux", score: -200} else empty end),
        (if $formats["Bad Release Groups"]? then {format: $formats["Bad Release Groups"], name: "Bad Release Groups", score: -1000} else empty end)
    ]'
}

apply_radarr_quality_profiles() {
    local profiles_json="$1"
    local format_items_json="$2"

    echo "$profiles_json" | @jq@/bin/jq -c \
        --argjson formatItems "$format_items_json" '
        .[] |
        (reduce (.items[]? | select(.quality.name? and (.quality.name | test("2160p"))).quality.id) as $id (null; if . == null then $id else . end)) as $cutoffId |
        (.cutoff) as $existingCutoff |
        {
            id: .id,
            name: .name,
            payload: (
                .formatItems = $formatItems |
                .minFormatScore = -150 |
                .cutoffFormatScore = 100 |
                .upgradeAllowed = true |
                .cutoff = ($cutoffId // $existingCutoff) |
                (.items[]? | select(.quality.name? and (.quality.name | test("2160p")))).allowed = true |
                (.items[]? | select(.quality.name? and (.quality.name | test("1080p")))).allowed = true |
                (.items[]? | select(.quality.name? and (.quality.name | test("720p")))).allowed = true |
                (.items[]? | select(.quality.name? and (.quality.name | test("Remux")))).allowed = false |
                (.items[]? | select(.quality.name? and ((.quality.name | test("480p")) or (.quality.name | test("DVD")) or (.quality.name | test("SDTV"))))).allowed = false
            )
        }' | while read -r profile_payload; do
            local profile_id
            profile_id=$(@jq@/bin/jq '.id' <<< "$profile_payload")
            local profile_name
            profile_name=$(@jq@/bin/jq -r '.name' <<< "$profile_payload")
            local payload
            payload=$(@jq@/bin/jq -c '.payload' <<< "$profile_payload")

            echo "  Updating profile: $profile_name"
            radarr_api PUT "/api/v3/qualityprofile/$profile_id" "$payload" > /dev/null
        done
}

set_radarr_default_profile() {
    local profiles_json="$1"
    local profile_json
    profile_json=$(@jq@/bin/jq -c '.[] | select(.name | test("(?i)4k|2160"))' <<< "$profiles_json" | head -n1)

    if [ -z "$profile_json" ]; then
        profile_json=$(@jq@/bin/jq -c '.[] | select(.name == "HD - 720p/1080p")' <<< "$profiles_json" | head -n1)
    fi

    if [ -z "$profile_json" ]; then
        echo "  Could not find a suitable profile for reassignment; skipping"
        return
    fi

    local profile_id
    profile_id=$(@jq@/bin/jq '.id' <<< "$profile_json")
    local profile_name
    profile_name=$(@jq@/bin/jq -r '.name' <<< "$profile_json")

    local movies_json
    movies_json=$(radarr_api GET "/api/v3/movie")
    local movie_ids_json
    movie_ids_json=$(@jq@/bin/jq '[.[].id]' <<< "$movies_json")
    local movie_count
    movie_count=$(@jq@/bin/jq 'length' <<< "$movie_ids_json")

    if [ "$movie_count" -eq 0 ]; then
        echo "  No movies to update"
        return
    fi

    local payload
    payload=$(@jq@/bin/jq -n \
        --argjson ids "$movie_ids_json" \
        --argjson profile "$profile_id" \
        '{movieIds: $ids, qualityProfileId: $profile, moveFiles: false}')

    radarr_api PUT "/api/v3/movie/editor" "$payload" > /dev/null
    echo "  Updated $movie_count movies to use optimized profile ($profile_name)"
}

build_sonarr_format_map() {
    @jq@/bin/jq -c 'map({key: .name, value: .id}) | from_entries' <<< "$(sonarr_formats)"
}

build_sonarr_format_items() {
    local format_map_json="$1"
    @jq@/bin/jq -cn --argjson formats "$format_map_json" '[
        (if $formats["x265/HEVC"]? then {format: $formats["x265/HEVC"], name: "x265/HEVC", score: 100} else empty end),
        (if $formats["Trusted HEVC Groups"]? then {format: $formats["Trusted HEVC Groups"], name: "Trusted HEVC Groups", score: 50} else empty end),
        (if $formats["Re-Encoded"]? then {format: $formats["Re-Encoded"], name: "Re-Encoded", score: -100} else empty end),
        (if $formats["Bad Release Groups"]? then {format: $formats["Bad Release Groups"], name: "Bad Release Groups", score: -1000} else empty end)
    ]'
}

apply_sonarr_quality_profiles() {
    local profiles_json="$1"
    local format_items_json="$2"

    echo "$profiles_json" | @jq@/bin/jq -c \
        --argjson formatItems "$format_items_json" '
        .[] | {
            id: .id,
            name: .name,
            payload: (
                .formatItems = $formatItems |
                .minFormatScore = -1000 |
                .cutoffFormatScore = 10000
            )
        }' | while read -r profile_payload; do
            local profile_id
            profile_id=$(@jq@/bin/jq '.id' <<< "$profile_payload")
            local profile_name
            profile_name=$(@jq@/bin/jq -r '.name' <<< "$profile_payload")
            local payload
            payload=$(@jq@/bin/jq -c '.payload' <<< "$profile_payload")

            echo "  Updating profile: $profile_name"
            sonarr_api PUT "/api/v3/qualityprofile/$profile_id" "$payload" > /dev/null
        done
}

ensure_sonarr_release_profile() {
    local release_profiles
    release_profiles=$(sonarr_api GET "/api/v3/releaseprofile")

    if echo "$release_profiles" | @jq@/bin/jq -e '.[] | select(.name == "Block Bad Encoders")' > /dev/null 2>&1; then
        echo "  Bad encoder blocking profile already exists"
    else
        echo "  Creating bad encoder blocking profile..."
        sonarr_api POST "/api/v3/releaseprofile" '{
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
        }' > /dev/null
        echo "  Bad encoder blocking profile created"
    fi
}

if [ -z "$RADARR_API_KEY" ]; then
    echo "⚠ Could not find Radarr API key in /var/lib/radarr/.config/Radarr/config.xml"
    echo "  This is normal on fresh installations - Radarr needs to start first"
    echo "  Configuration will be applied on next boot after Radarr generates its config"

    if [ -n "$SONARR_API_KEY" ]; then
        echo "  Found Sonarr API key, will configure Sonarr only"
    else
        echo "  No Sonarr API key found either - exiting"
        exit 0
    fi
fi

if [ -n "$RADARR_API_KEY" ]; then
    echo "=== Configuring Radarr for optimal quality ==="
    echo "Target: 4K HEVC when available, 1080p HEVC fallback"
    echo ""

    cleanup_duplicate_formats

    echo "Creating/updating custom formats..."
    radarr_sync_format "x265/HEVC" '{
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

    radarr_sync_format "Bad Release Groups" '{
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

    radarr_sync_format "Trusted HEVC Groups" '{
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

    radarr_sync_format "Re-Encoded" '{
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

    radarr_sync_format "x264/H.264" '{
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

    radarr_sync_format "4K/2160p" '{
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

    radarr_delete_format "Excessive Size"

    radarr_sync_format "Remux" '{
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

    radarr_sync_format "Foreign Film" '{
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

    configure_radarr_quality_definitions

    echo ""
    echo "Getting custom format IDs..."
    radarr_invalidate_formats
    radarr_format_map=$(build_radarr_format_map)
    radarr_format_items=$(build_radarr_format_items "$radarr_format_map")

    echo "Updating quality profiles with optimal scoring..."
    radarr_profiles_json=$(radarr_api GET "/api/v3/qualityprofile")
    apply_radarr_quality_profiles "$radarr_profiles_json" "$radarr_format_items"

    echo ""
    echo "Setting HD - 720p/1080p as default profile for all movies..."
    set_radarr_default_profile "$radarr_profiles_json"
fi

# Configure Sonarr if available (v4 uses Custom Formats like Radarr)
if [ -n "$SONARR_API_KEY" ]; then
    echo ""
    echo "=== Configuring Sonarr ==="
    echo "Creating custom formats for Sonarr..."

    sonarr_sync_format "x265/HEVC" '{
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

    sonarr_sync_format "Bad Release Groups" '{
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

    sonarr_sync_format "Trusted HEVC Groups" '{
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

    sonarr_sync_format "Re-Encoded" '{
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

    ensure_sonarr_release_profile

    echo "Updating Sonarr quality profiles with custom format scoring..."
    sonarr_invalidate_formats
    sonarr_format_map=$(build_sonarr_format_map)
    sonarr_format_items=$(build_sonarr_format_items "$sonarr_format_map")
    sonarr_profiles_json=$(sonarr_api GET "/api/v3/qualityprofile")
    apply_sonarr_quality_profiles "$sonarr_profiles_json" "$sonarr_format_items"

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
