#!/bin/bash
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Show usage information
usage() {
    echo "Usage: $0 KERNEL_VERSION [SOURCE_DIR]"
    echo "Transfer kernel files to organized directory structure"
    echo ""
    echo "Arguments:"
    echo "  KERNEL_VERSION  Version string for the kernel (e.g., 6.1.0)"
    echo "  SOURCE_DIR      Source directory containing files (default: ~/)"
    echo ""
    echo "Files to transfer:"
    echo "  - All files matching pattern *KERNEL_VERSION*"
    echo "  - Kernel Image from ~/Amlogic_s905-kernel/arch/arm64/boot/Image"
    echo ""
    echo "Examples:"
    echo "  $0 6.1.0"
    echo "  $0 6.1.0 /path/to/source"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -n, --dry-run   Show what would be transferred without copying"
}

# Validate kernel version format
validate_kernel_version() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        log_error "Kernel version is required"
        usage
        exit 1
    fi
    
    if [[ ! $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?(-.*)?$ ]]; then
        log_warn "Unusual kernel version format: $version"
        log_warn "Expected format: X.Y.Z or X.Y.Z-suffix"
    fi
}

# Find and list files to transfer
find_transfer_files() {
    local source_dir="$1"
    local kver="$2"
    local dry_run="$3"
    
    local -a found_files=()
    local kernel_image_path="$source_dir/Amlogic_s905-kernel/arch/arm64/boot/Image"
    
    log_step "Searching for files in $source_dir..."
    
    # Find files matching kernel version pattern
    while IFS= read -r -d '' file; do
        found_files+=("$file")
    done < <(find "$source_dir" -maxdepth 1 -name "*${kver}*" -type f -print0 2>/dev/null)
    
    # Check for kernel Image
    if [[ -f "$kernel_image_path" ]]; then
        found_files+=("$kernel_image_path")
    else
        log_warn "Kernel Image not found at: $kernel_image_path"
    fi
    
    if [[ ${#found_files[@]} -eq 0 ]]; then
        log_error "No files found matching pattern *${kver}*"
        exit 1
    fi
    
    log_info "Found ${#found_files[@]} files to transfer:"
    for file in "${found_files[@]}"; do
        local size
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        echo "  - $(basename "$file") ($((size / 1024 / 1024))MB)"
    done
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "Dry run mode - no files will be copied"
        return 0
    fi
    
    echo "${found_files[@]}"
}

# Transfer files with verification
transfer_files() {
    local dest_dir="$1"
    shift
    local files=("$@")
    
    log_step "Transferring files to $dest_dir..."
    
    local transferred=0
    local failed=0
    
    for file in "${files[@]}"; do
        local basename_file
        basename_file=$(basename "$file")
        local dest_file="$dest_dir/$basename_file"
        
        log_info "Copying: $basename_file"
        
        if cp -v "$file" "$dest_file"; then
            # Verify copy
            if [[ -f "$dest_file" ]]; then
                local orig_size dest_size
                orig_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
                dest_size=$(stat -f%z "$dest_file" 2>/dev/null || stat -c%s "$dest_file" 2>/dev/null)
                
                if [[ "$orig_size" -eq "$dest_size" ]]; then
                    ((transferred++))
                    log_info "✓ Successfully copied $basename_file"
                else
                    ((failed++))
                    log_error "✗ Size mismatch for $basename_file (orig: $orig_size, dest: $dest_size)"
                fi
            else
                ((failed++))
                log_error "✗ Destination file not found: $dest_file"
            fi
        else
            ((failed++))
            log_error "✗ Failed to copy: $file"
        fi
    done
    
    log_info "Transfer summary: $transferred successful, $failed failed"
    
    if [[ $failed -gt 0 ]]; then
        log_error "Some files failed to transfer"
        exit 1
    fi
}

# Main function
main() {
    local kver="${1:-}"
    local source_dir="${2:-$HOME}"
    local dry_run="${DRY_RUN:-false}"
    
    # Validate inputs
    validate_kernel_version "$kver"
    
    if [[ ! -d "$source_dir" ]]; then
        log_error "Source directory does not exist: $source_dir"
        exit 1
    fi
    
    local dest_dir="$kver"
    
    log_info "Starting file transfer for kernel version: $kver"
    log_info "Source directory: $source_dir"
    log_info "Destination directory: $dest_dir"
    
    # Find files to transfer
    local files_output
    files_output=$(find_transfer_files "$source_dir" "$kver" "$dry_run")
    
    if [[ "$dry_run" == "true" ]]; then
        return 0
    fi
    
    # Convert output to array
    local -a files
    read -ra files <<< "$files_output"
    
    # Create destination directory
    log_step "Creating destination directory: $dest_dir"
    if ! mkdir -p "$dest_dir"; then
        log_error "Failed to create destination directory: $dest_dir"
        exit 1
    fi
    
    # Transfer files
    transfer_files "$dest_dir" "${files[@]}"
    
    log_info "Transfer completed successfully!"
    log_info "Files are now organized in: $(realpath "$dest_dir")"
    
    # Show final directory contents
    log_step "Final directory contents:"
    ls -la "$dest_dir"
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Run main function
main "$@"
