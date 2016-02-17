## START TEMPLATE
acl purge {
	"localhost";
	"10.255.255.20";
	"10.255.255.6";
	"85.159.147.110";
	"85.159.147.27";
}

sub vcl_recv {

	// Add a Surrogate-Capability header to announce ESI support.
	set req.http.Surrogate-Capability = "abc=ESI/1.0";

	# Normalize the header, remove the port
	set req.http.host = regsub(req.http.host, ":[0-9]+", "");

	#set req.backend = more_prod;

	set req.http.X-Forwarded-For = client.ip;

	if (req.request == "PURGE") {
		if (!client.ip ~ purge) {
			error 405 "Not allowed";
		}
		return (lookup);
	}

	if (req.http.Cache-Control ~ "no-cache" && client.ip ~ purge) {
		set req.hash_always_miss = true;
	}

	if (req.request == "BAN") {
		if(!client.ip ~ purge) {
			error 405 "Not allowed.";
		}
	#ban("obj.http.X-Host ~ " + req.http.X-Host
                #+ " && obj.http.X-Url ~ " + req.http.X-Url
                #+ " && obj.http.content-type ~ " + req.http.X-Content-Type
            #);
		if (req.http.X-Cache-Tags) {
			ban("obj.http.X-Host ~ " + req.http.X-Host
				+ " && obj.http.X-Url ~ " + req.http.X-Url
				+ " && obj.http.content-type ~ " + req.http.X-Content-Type
				+ " && obj.http.X-Cache-Tags ~ " + req.http.X-Cache-Tags
			);
		} else {
			ban("req.url ~ "+req.url+" && req.http.host == "+req.http.host);
		}
		error 200 "Banned " + req.http.host + " " + req.url;
	}

	if (req.url ~ "^/(carrello|carrello-2|cart|my-account|checkout|addons)") {
		return (pass);
	}
	if ( req.url ~ "\?add-to-cart=" ) {
		return (pass);
	}

# wordpress
	if (req.url ~ "wp-(login|admin|signup)|login|preview|admin-ajax.php"){
		return (pass);
	}

	if (req.http.Cookie) {
		if (req.http.cookie !~ "PHPSESSID" && req.http.cookie ~ "REMEMBERME") {
			return(pass);
		}

		if (req.http.Cookie ~ "wordpress_logged_in_" || req.http.Cookie ~ "woocommerce_" || req.http.Cookie ~ "wp_postpass" || req.http.Cookie ~ "DokuWiki"){
			return (pass);
		} else {
			if (req.url ~ "\.(png|gif|jpg|swf|css|js)\??.*?$") {
				unset req.http.Cookie;
			} else {
				/* Warning: Not a pretty solution */
				/* Prefix header containing cookies with ';' */
				set req.http.Cookie = ";" + req.http.Cookie;
				/* Remove any spaces after ';' in header containing cookies */
				set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
				/* Prefix cookies we want to preserve with one space */
				/* 'S{1,2}ESS[a-z0-9]+' is the regular expression matching a Drupal session cookie ({1,2} added for HTTPS support) */
				/* 'NO_CACHE' is usually set after a POST request to make sure issuing user see the results of his post */
				/* Keep in mind we should add here any cookie that should reach the backend such as splahs avoiding cookies */
				set req.http.Cookie = regsuball(req.http.Cookie, ";(ow_cookie_notice|PHPSESSID|NO_CACHE)=", "; \1=");
				/* Remove from the header any single Cookie not prefixed with a space until next ';' separator */
				set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
				/* Remove any '; ' at the start or the end of the header */
				set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
			}

			if (req.http.Cookie == "") {
				/* If there are no remaining cookies, remove the cookie header. */
				unset req.http.Cookie;
			}
		}
	}

}

sub vcl_fetch {
	// Check for ESI acknowledgement and remove Surrogate-Control header
	if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
		unset beresp.http.Surrogate-Control;
		set beresp.do_esi = true;
	}

	set beresp.http.X-Backend = beresp.backend.name;

	/* By default, Varnish3 ignores Cache-Control: no-cache and private
	   https://www.varnish-cache.org/docs/3.0/tutorial/increasing_your_hitrate.html#cache-control
	 */
	if (beresp.http.Cache-Control ~ "private" ||
	 	beresp.http.Cache-Control ~ "no-cache" ||
	 	beresp.http.Cache-Control ~ "no-store"
	) {
	 	return (hit_for_pass);
	}

	if (req.url ~ "wp-(login|admin)|login" || req.url ~ "preview=true") {
		return (hit_for_pass);
	}

	set beresp.ttl = 4h;
	if (beresp.status >= 400){
		set beresp.ttl = 5m;
	}
# strip the cookie before the image is inserted into cache.
	if (req.url ~ "\.(png|gif|jpg|swf|css|js)$") {
		unset beresp.http.set-cookie;
	}

	# Set ban-lurker friendly custom headers
	set beresp.http.X-Url = req.url;
	set beresp.http.X-Host = req.http.host;
}

sub vcl_deliver {
	remove resp.http.X-Powered-By;
	remove resp.http.Server;

	if(obj.hits > 0){
		set resp.http.X-Cache = "HIT:" + obj.hits;
	} else {
		set resp.http.X-Cache = "MISS";
	}

	# Keep ban-lurker headers only if debugging is enabled
	if (!resp.http.X-Cache-Debug) {
		# Remove ban-lurker friendly custom headers when delivering to client
		unset resp.http.X-Url;
		unset resp.http.X-Host;
		unset resp.http.X-Cache-Tags;
	}
}

sub vcl_hash {
	/* Hash cookie data */
# As requests with same URL and host can produce diferent results when issued with different cookies,
# we need to store items hashed with the associated cookies. Note that cookies are already sanitized when we reach this point.
	if (req.http.Cookie) {
		/* Include cookie in cache hash */
		hash_data(req.http.Cookie);
	}
}

sub vcl_hit {
	if (req.request == "PURGE") {
		purge;
		error 204 "Purged";
	}
}

# The purge in vcl_miss is necessary to purge all variants in the cases where
# you hit an object, but miss a particular variant.
sub vcl_miss {
	if (req.request == "PURGE") {
		purge;
		error 204 "Purged (Not in cache)";
	}
}

sub vcl_error {
    if (obj.status == 750) {
        set obj.http.Location = obj.response;
        set obj.status = 301;
        return(deliver);
    }
}
## END TEMPLATE
