#!/bin/bash
# shellcheck disable=SC2086  # Word splitting intended for argument handling
set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Default configuration
DEFAULT_BUILD_DIR="./build"
DEFAULT_KVER="5.9.1"

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
    echo "Usage: $0 [KERNEL_VERSION] [BUILD_DIR]"
    echo "Download and set up Linux kernel source"
    echo ""
    echo "Arguments:"
    echo "  KERNEL_VERSION  Kernel version to download (default: $DEFAULT_KVER)"
    echo "  BUILD_DIR       Build directory (default: $DEFAULT_BUILD_DIR)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Use defaults"
    echo "  $0 6.1.10             # Specific kernel version"
    echo "  $0 6.1.10 /tmp/build  # Custom build directory"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -l, --list      List available kernel versions"
}

# List available kernel versions
list_kernel_versions() {
    echo "Fetching available kernel versions..."
    local major_versions=("4" "5" "6")
    
    # Check for available download tools
    local download_cmd=""
    if command -v curl &>/dev/null; then
        download_cmd="curl -s"
    elif command -v wget &>/dev/null; then
        download_cmd="wget -qO-"
    else
        log_error "Neither curl nor wget is available for fetching version list"
        return 1
    fi
    
    for major in "${major_versions[@]}"; do
        echo "Kernel v${major}.x versions:"
        if ! $download_cmd "https://cdn.kernel.org/pub/linux/kernel/v${major}.x/" | \
            grep -oE 'linux-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.xz' | \
            sed 's/linux-//g' | sed 's/\.tar\.xz//g' | \
            sort -V | tail -10; then
            echo "Failed to fetch versions for v${major}.x"
        fi
        echo
    done
}

# Validate kernel version format
validate_kernel_version() {
    local version="$1"
    
    if [[ ! $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "Invalid kernel version format: $version"
        log_error "Expected format: X.Y or X.Y.Z (e.g., 5.9.1, 6.1.10)"
        exit 1
    fi
}

# Check available disk space
check_disk_space() {
    local build_dir="$1"
    local required_space=2000000  # 2GB in KB
    local parent_dir
    
    parent_dir=$(dirname "$(realpath "$build_dir")")
    local available_space
    available_space=$(df "$parent_dir" | awk 'NR==2 {print $4}')
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space. Required: $((required_space / 1024))MB, Available: $((available_space / 1024))MB"
        exit 1
    fi
    
    log_info "Disk space check passed (Available: $((available_space / 1024))MB)"
}

# Verify download integrity
verify_download() {
    local file="$1"
    local expected_size="${2:-}"
    
    if [[ ! -f "$file" ]]; then
        log_error "Download failed: $file not found"
        return 1
    fi
    
    local file_size
    file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    # Basic size check (kernel source should be at least 100MB)
    if [[ $file_size -lt 100000000 ]]; then
        log_error "Downloaded file appears corrupted (size: $((file_size / 1024 / 1024))MB)"
        return 1
    fi
    
    log_info "Download verified (size: $((file_size / 1024 / 1024))MB)"
    return 0
}

# Download kernel with retry mechanism
download_kernel() {
    local url="$1"
    local filename="$2"
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        log_step "Downloading kernel source (attempt $((retry + 1))/$max_retries)..."
        
        # Try wget first, fallback to curl
        local download_success=false
        
        if command -v wget &>/dev/null; then
            if wget --progress=bar:force:noscroll --timeout=30 --tries=1 "$url"; then
                download_success=true
            fi
        elif command -v curl &>/dev/null; then
            if curl -L --progress-bar --connect-timeout 30 -o "$filename" "$url"; then
                download_success=true
            fi
        fi
        
        if [[ "$download_success" == "true" ]]; then
            if verify_download "$filename"; then
                return 0
            else
                log_warn "Download verification failed, retrying..."
                rm -f "$filename"
            fi
        else
            log_warn "Download failed, retrying..."
        fi
        
        ((retry++))
        [[ $retry -lt $max_retries ]] && sleep 5
    done
    
    log_error "Failed to download kernel after $max_retries attempts"
    return 1
}

# Cleanup function
cleanup() {
    log_warn "Script interrupted, cleaning up..."
    [[ -n "${temp_files:-}" ]] && rm -f "${temp_files[@]}"
    exit 1
}

# Main function
main() {
    local kver="${1:-$DEFAULT_KVER}"
    local build_dir="${2:-$DEFAULT_BUILD_DIR}"
    
    # Validate inputs
    validate_kernel_version "$kver"
    
    # Prepare variables
    local kernel_name="linux-$kver"
    local filename="${kernel_name}.tar.xz"
    local major_version="${kver:0:1}"
    local base_url="https://cdn.kernel.org/pub/linux/kernel/v${major_version}.x"
    local download_url="$base_url/$filename"
    
    log_info "Setting up kernel $kver in $build_dir"
    log_info "Download URL: $download_url"
    
    # Set up signal handlers
    trap cleanup INT TERM
    
    # Pre-flight checks
    check_disk_space "$build_dir"
    
    # Create and enter build directory
    log_step "Creating build directory: $build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Check if kernel source already exists
    if [[ -d "$kernel_name" ]]; then
        log_warn "Kernel directory $kernel_name already exists"
        
        # Auto-remove in CI environments or if FORCE_REINSTALL is set
        if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ "${FORCE_REINSTALL:-}" == "true" ]]; then
            log_info "Auto-removing existing directory in CI environment..."
            rm -rf "$kernel_name"
        elif [[ -t 0 ]]; then  # Interactive mode
            read -p "Remove existing directory and re-download? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$kernel_name"
                log_info "Removed existing directory"
            else
                log_info "Using existing kernel source"
                cd "$kernel_name"
                log_info "Ready to build in $(pwd)"
                return 0
            fi
        else
            # Non-interactive - use existing by default
            log_info "Non-interactive mode: using existing kernel source (use FORCE_REINSTALL=true to override)"
            cd "$kernel_name"
            log_info "Ready to build in $(pwd)"
            return 0
        fi
    fi
    
    # Download kernel source
    if ! download_kernel "$download_url" "$filename"; then
        exit 1
    fi
    
    # Extract kernel source
    log_step "Extracting kernel source..."
    if ! tar -xf "$filename"; then
        log_error "Failed to extract kernel source"
        exit 1
    fi
    
    # Cleanup downloaded archive
    rm "$filename"
    log_info "Cleaned up archive file"
    
    # Enter kernel directory
    cd "$kernel_name"
    
    # Verify extraction
    if [[ ! -f "Makefile" ]] || [[ ! -f "Kconfig" ]]; then
        log_error "Kernel source extraction appears incomplete"
        exit 1
    fi
    
    log_info "Kernel setup completed successfully!"
    log_info "Kernel source ready in: $(pwd)"
    log_info "Next steps:"
    echo "  1. Configure kernel: make menuconfig"
    echo "  2. Build kernel: make -j\$(nproc)"
    echo "  3. Install modules: make modules_install"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    -l|--list)
        list_kernel_versions
        exit 0
        ;;
esac

# Run main function
main "$@"
