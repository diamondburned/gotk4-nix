#!/usr/bin/env bash
set -e
set +x

main() {
	repo="$1"
	[[ ! $repo ]] && fatal 'Missing $1.'

	matches=( "${@:2}" )
	[[ ${#matches[@]} == 0 ]] && fatal 'No files given.'

	files=( $(find "${matches[@]}" -type f) )
	[[ ${#files[@]} == 0 ]] && fatal "No files given."

	[[ $GITHUB_REF =~ refs/tags/(.*) ]] \
		&& tag=${BASH_REMATCH[1]} \
		|| fatal '$GITHUB_REF'" doesn't match refs/tags/*."
	
	release=$(ghcurl "https://api.github.com/repos/$repo/releases/tags/$tag")
	releaseID=$(jq '.id' <<< "$release")
	
	for file in "${files[@]}"; {
		name=$(basename "$file")
		ghcurl \
			-X POST \
			-H "Content-Type: application/gzip" \
			--data-binary "@$file" \
			"https://uploads.github.com/repos/$repo/releases/$releaseID/assets?name=$name" > /dev/null
	}
}

fatal() {
	echo "$@" 1>&2
	exit 1
}

ghcurl() {
	[[ ! $GITHUB_TOKEN ]] && {
		GITHUB_TOKEN=$(< ~/.github-token) || fatal "Missing token file ~/.github-token."
	}

	curl \
		-H "Authorization: token $GITHUB_TOKEN" \
		-H "Accept: application/vnd.github.v3+json" \
		-s \
		"$@"
}

main "$@"
