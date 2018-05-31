/*!
 * Functions for dealing with GitHub projects.  
 *
 * When functions ask for `owner` and `repo`, they're
 * referring to GitHub repository names and owners.  
 * For example, the project at `https://github.com/VoltLang/Volta`
 * has a owner of `VoltLang` and an owner of `Volta`.
 */
module bs.github;

import http = watt.http;
import json = watt.json;
import text = watt.text.string;

struct ReleaseFile
{
	filename: string;
	url: string;
	size: size_t;
}

/*!
 * Get information about a specific file from a specific project release.
 * @Returns `true` if a file ending in `targetEnd` does exist for the latest
 * release from the specified project.
 */
fn getReleaseFile(owner: string, repo: string, targetEnd: string, out releaseFile: ReleaseFile) bool
{
	releaseJson := getLatestReleaseJson(owner, repo);
	if (releaseJson is null) {
		return false;
	}

	jsonRoot := json.parse(releaseJson);
	return searchAssets(jsonRoot, targetEnd, out releaseFile);
}

private:

//! Get the json file from the github api for the given project.
fn getLatestReleaseJson(owner: string, repo: string) string
{
	h := new http.Http();
	r := new http.Request(h);
	r.server = "api.github.com";
	r.url    = new "/repos/${owner}/${repo}/releases/latest";
	r.port   = 443;
	r.secure = true;
	h.loop();
	if (r.errorGenerated()) {
		return null;
	}
	return r.getString();
}

/*!
 * If the release json `root` has an asset ending in
 * `targetEnd`, fill out `releaseFile` and return `true`.
 */
fn searchAssets(root: json.Value, targetEnd: string, out releaseFile: ReleaseFile) bool
{
	if (!root.hasObjectKey("assets")) {
		return false;
	}
	assetsArrayVal := root.lookupObjectKey("assets");
	if (assetsArrayVal.type() != json.DomType.Array) {
		return false;
	}
	assetsArray := assetsArrayVal.array();

	foreach (assetRoot; assetsArray) {
		if (!assetRoot.hasObjectKey("name")) {
			continue;
		}
		name := assetRoot.lookupObjectKey("name");
		if (name.type() != json.DomType.String || !text.endsWith(name.str(), targetEnd)) {
			continue;
		}

		if (!assetRoot.hasObjectKey("browser_download_url")) {
			return false;
		}
		url := assetRoot.lookupObjectKey("browser_download_url");
		if (url.type() != json.DomType.String) {
			return false;
		}

		if (!assetRoot.hasObjectKey("size")) {
			return false;
		}
		sz := assetRoot.lookupObjectKey("size");
		if (sz.type() != json.DomType.Long) {
			continue;
		}

		releaseFile.filename = name.str();
		releaseFile.url      = url.str();
		releaseFile.size     = cast(size_t)sz.integer();
		return true;
	}
	return false;
}
