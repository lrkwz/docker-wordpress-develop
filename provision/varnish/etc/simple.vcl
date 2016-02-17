##
import std; // import logging
##BACKEND

backend default {
	.host = "backend";
	.port = "80";
}

acl purge {
	"localhost";
	"127.17.0.1";
}

sub vcl_recv {

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
}

sub vcl_fetch {
	set beresp.http.X-Backend = beresp.backend.name;


	# Set ban-lurker friendly custom headers
	set beresp.http.X-Url = req.url;
	set beresp.http.X-Host = req.http.host;
}

sub vcl_deliver {
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
