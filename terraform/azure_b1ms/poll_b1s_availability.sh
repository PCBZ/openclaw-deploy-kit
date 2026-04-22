#!/usr/bin/env bash

set -euo pipefail

SKU="Standard_B2pts_v2"
REGION="centralus"
INTERVAL_SECONDS=7200
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
	cat <<'EOF'
Usage:
	./poll_b1s_availability.sh [options]

Options:
	-s, --sku <name>         VM SKU to check (default: Standard_B2pts_v2)
	-r, --region <name>      Region to check and apply (default: centralus)
	-i, --interval <sec>     Poll interval seconds (default: 7200)
	-h, --help               Show help

Examples:
	./poll_b1s_availability.sh
	./poll_b1s_availability.sh -r eastus -i 7200
EOF
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-s|--sku)
				SKU="$2"
				shift 2
				;;
			-r|--region)
				REGION="$2"
				shift 2
				;;
			-i|--interval)
				INTERVAL_SECONDS="$2"
				shift 2
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				echo "Unknown argument: $1" >&2
				usage
				exit 1
				;;
		esac
	done
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Required command not found: $1" >&2
		exit 1
	fi
}

check_region() {
	local region="$1"
	local reasons

	reasons=$(az vm list-skus \
		--location "$region" \
		--resource-type virtualMachines \
		--all \
		--query "[?name=='${SKU}'].restrictions[].reasonCode" \
		-o tsv 2>/dev/null | tr '\n' ',' | sed 's/,$//')

	if [[ -z "$reasons" ]]; then
		echo "AVAILABLE"
		return
	fi

	if [[ "$reasons" == *"NotAvailableForSubscription"* ]]; then
		echo "BLOCKED_BY_SUBSCRIPTION ($reasons)"
		return
	fi

	echo "RESTRICTED ($reasons)"
}

run_apply_once() {
	set +e
	terraform apply --auto-approve -var "location=${REGION}" -var "vm_size=${SKU}"
	local rc=$?
	set -e
	return "$rc"
}

main() {
	require_cmd az
	require_cmd terraform
	parse_args "$@"
	cd "$SCRIPT_DIR"

	echo "Checking SKU: $SKU"
	echo "Region: $REGION"
	echo "Interval: ${INTERVAL_SECONDS}s"

	while true; do
		local now
		local status
		now=$(date '+%Y-%m-%d %H:%M:%S')
		echo
		echo "[$now] Checking ${REGION} then running terraform apply..."

		status=$(check_region "$REGION")
		echo "  ${REGION}: ${status}"

		if run_apply_once; then
			echo "Terraform apply succeeded. Exiting."
			exit 0
		fi

		echo "Terraform apply failed. Will retry in ${INTERVAL_SECONDS}s."

		sleep "$INTERVAL_SECONDS"
	done
}

main "$@"
