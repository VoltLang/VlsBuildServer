/*!
 * Get things from the internet!
 */
module bs.net;

import io = watt.io;
import http = watt.http;
import file = watt.io.file;
import text = watt.text.string;

/*!
 * Download the file pointed to by `url` to disk at `filename`.  
 *
 * `url` should include the protocol ('https://' etc). If `expectedSize` is
 * greater than zero, then if `expectedSize` bytes are not downloaded
 * exactly, this function will fail.
 *
 * @Returns `true` on success.
 */
fn download(url: string, filename: string, expectedSize: size_t = 0) bool
{
	io.writeln(new "Downloading ${url} (${expectedSize} bytes) to ${filename}");
	h := new http.Http();
	r := buildRequest(h, url);
	if (r is null) {
		return false;
	}
	h.loop();
	if (!r.completed() ||
		r.errorGenerated() ||
		(expectedSize > 0 && r.bytesDownloaded() != expectedSize)) {
		return false;
	}
	file.write(r.getData(), filename);
	return true;
}

private:

/*!
 * Build a Request from the given URL string.
 *
 * Expects leading 'http(s)://'.
 * Not general purpose; only tested on our github.com urls.
 */
fn buildRequest(h: http.Http, url: string) http.Request
{
	req := new http.Request(h);
	if (!eatUrlProtocol(ref url, req)) {
		return null;
	}
	if (!eatUrlServer(ref url, req)) {
		return null;
	}
	if (!eatUrlUrl(ref url, req)) {
		return null;
	}
	return req;
}

/*!
 * If `url` has a valid protocol, remove it and set `req` appropriately.
 * Otherwise, return `false`.  
 */
fn eatUrlProtocol(ref url: string, req: http.Request) bool
{
	if (url.length <= 6) {
		return false;
	}
	if (text.startsWith(url, "http://")) {
		url = url["http://".length .. $];
		req.secure = false;
		req.port = 80;
		return true;
	} else if (text.startsWith(url, "https://")) {
		url = url["https://".length .. $];
		req.secure = true;
		req.port = 443;
		return true;
	}
	return false;
}

/*!
 * Eat the server component of `url` and set `req` appropriately.
 *
 * Assumes the protocol has been removed already, and that there's a '/' dividing
 * the server and url proper.
 */
fn eatUrlServer(ref url: string, req: http.Request) bool
{
	idx := text.indexOf(url, "/");
	if (idx <= 0) {
		return false;
	}
	req.server = url[0 .. cast(size_t)idx];
	url = url[idx .. $];
	return true;
}

//! Call after the eat*Protocol and Server functions.
fn eatUrlUrl(ref url: string, req: http.Request) bool
{
	req.url = url;
	url = null;
	return true;
}
