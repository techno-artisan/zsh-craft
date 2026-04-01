#!/usr/bin/env bash
# Migration script for alias management system restructuring
# This script migrates existing aliases from the old structure to the new modular structure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALIASES_DIR="$SCRIPT_DIR/home/aliases"

echo "Starting alias migration..."

# Create directories if they don't exist
mkdir -p "$ALIASES_DIR/global" "$ALIASES_DIR/arch" "$ALIASES_DIR/package-manager" "$ALIASES_DIR/user"

# Function to extract aliases from a file and write to appropriate group files
migrate_file() {
    local source_file="$1"
    local category="$2"
    local output_dir="$3"

    if [[ ! -f "$source_file" ]]; then
        echo "Warning: Source file $source_file not found, skipping..."
        return
    fi

    echo "Migrating $source_file..."

    local current_group=""
    local group_content=""

    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Check for group comments
        if [[ "$line" =~ ^#[[:space:]]*(.+)$ ]]; then
            local comment="${BASH_REMATCH[1]}"

            # If we have content for the previous group, write it
            if [[ -n "$current_group" && -n "$group_content" ]]; then
                write_group_file "$current_group" "$group_content" "$output_dir"
                group_content=""
            fi

            # Determine group based on comment
            case "$comment" in
                *"basic"*)
                    current_group="basic"
                    ;;
                *"composer"*)
                    current_group="composer"
                    ;;
                *"docker"*)
                    current_group="docker"
                    ;;
                *"docker compose"*|*"docker-compose"*)
                    current_group="docker-compose"
                    ;;
                *"git"*)
                    current_group="git"
                    ;;
                *"go"*)
                    current_group="go"
                    ;;
                *"PI"*|*"pi"*)
                    current_group="pi"
                    ;;
                *"apt"*)
                    current_group="apt"
                    ;;
                *"apk"*)
                    current_group="apk"
                    ;;
                *)
                    # If no specific group, continue with current
                    ;;
            esac

            # Add the comment to content
            group_content+="$line"$'\n'
        else
            # Add non-comment lines to current group
            group_content+="$line"$'\n'
        fi
    done < "$source_file"

    # Write the last group
    if [[ -n "$current_group" && -n "$group_content" ]]; then
        write_group_file "$current_group" "$group_content" "$output_dir"
    fi
}

# Function to write group file
write_group_file() {
    local group="$1"
    local content="$2"
    local output_dir="$3"

    local filename="$output_dir/${group}.sh"

    # Check if file already exists
    if [[ -f "$filename" ]]; then
        echo "Warning: $filename already exists, skipping..."
        return
    fi

    echo "Creating $filename..."
    cat > "$filename" << EOF
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# $(echo "$group" | sed 's/-/ /g' | sed 's/\b\w/\U&/g') aliases
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

$content
EOF
}

# Migrate global aliases
if [[ -f "$SCRIPT_DIR/home/.aliases.global" ]]; then
    migrate_file "$SCRIPT_DIR/home/.aliases.global" "global" "$ALIASES_DIR/global"
fi

# Migrate arch-specific aliases
for arch_file in "$SCRIPT_DIR/home/arch-specific"/*.aliases.*; do
    if [[ -f "$arch_file" ]]; then
        local arch_name
        arch_name=$(basename "$arch_file" | sed 's/\.aliases\.//')
        case "$arch_name" in
            pi)
                migrate_file "$arch_file" "arch" "$ALIASES_DIR/arch"
                ;;
            *)
                echo "Skipping arch file: $arch_file (manual migration needed)"
                ;;
        esac
    fi
done

# Migrate package-manager-specific aliases
for pm_file in "$SCRIPT_DIR/home/package-manager-specific"/.alias_*; do
    if [[ -f "$pm_file" ]]; then
        local pm_name
        pm_name=$(basename "$pm_file" | sed 's/\.alias_//')
        migrate_file "$pm_file" "package-manager" "$ALIASES_DIR/package-manager"
    fi
done

echo "Migration completed!"
echo "Please review the generated files in $ALIASES_DIR"
echo "You may need to manually adjust some groupings or add additional structure."
