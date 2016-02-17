## Nexcessnet_Turpentine Varnish v3 VCL Template

## Custom C Code

C{
    // @source app/code/community/Nexcessnet/Turpentine/misc/uuid.c
    #include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <pthread.h>

static pthread_mutex_t lrand_mutex = PTHREAD_MUTEX_INITIALIZER;

void generate_uuid(char* buf) {
    pthread_mutex_lock(&lrand_mutex);
    long a = lrand48();
    long b = lrand48();
    long c = lrand48();
    long d = lrand48();
    pthread_mutex_unlock(&lrand_mutex);
    // SID must match this regex for Kount compat /^\w{1,32}$/
    sprintf(buf, "frontend=%08lx%04lx%04lx%04lx%04lx%08lx",
        a,
        b & 0xffff,
        (b & ((long)0x0fff0000) >> 16) | 0x4000,
        (c & 0x0fff) | 0x8000,
        (c & (long)0xffff0000) >> 16,
        d
    );
    return;
}

}C

## Imports

import std;

## Backends

backend default {
    .host = "backend";
    .port = "80";
   .first_byte_timeout = 300s;
   .between_bytes_timeout = 300s;
}


backend admin {
    .host = "backend";
    .port = "80";
   .first_byte_timeout = 21600s;
   .between_bytes_timeout = 21600s;
}


## ACLs

acl crawler_acl {
    "127.0.0.1";
}

acl debug_acl {
  "172.17.0.1";
}

## Custom Subroutines


sub generate_session {
    # generate a UUID and add `frontend=$UUID` to the Cookie header, or use SID
    # from SID URL param
    if (req.url ~ ".*[&?]SID=([^&]+).*") {
        set req.http.X-Varnish-Faked-Session = regsub(
            req.url, ".*[&?]SID=([^&]+).*", "frontend=\1");
    } else {
        C{
            char uuid_buf [50];
            generate_uuid(uuid_buf);
            VRT_SetHdr(sp, HDR_REQ,
                "\030X-Varnish-Faked-Session:",
                uuid_buf,
                vrt_magic_string_end
            );
        }C
    }
    if (req.http.Cookie) {
        # client sent us cookies, just not a frontend cookie. try not to blow
        # away the extra cookies
        std.collect(req.http.Cookie);
        set req.http.Cookie = req.http.X-Varnish-Faked-Session +
            "; " + req.http.Cookie;
    } else {
        set req.http.Cookie = req.http.X-Varnish-Faked-Session;
    }
}

sub generate_session_expires {
    # sets X-Varnish-Cookie-Expires to now + esi_private_ttl in format:
    #   Tue, 19-Feb-2013 00:14:27 GMT
    # this isn't threadsafe but it shouldn't matter in this case
    C{
        time_t now = time(NULL);
        struct tm now_tm = *gmtime(&now);
        now_tm.tm_sec += 3600;
        mktime(&now_tm);
        char date_buf [50];
        strftime(date_buf, sizeof(date_buf)-1, "%a, %d-%b-%Y %H:%M:%S %Z", &now_tm);
        VRT_SetHdr(sp, HDR_RESP,
            "\031X-Varnish-Cookie-Expires:",
            date_buf,
            vrt_magic_string_end
        );
    }C
}

## Varnish Subroutines

sub vcl_recv {


    # this always needs to be done so it's up at the top
    if (req.restarts == 0) {
        if (req.http.X-Forwarded-For) {
            set req.http.X-Forwarded-For =
                req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }

    if(false) {
        # save the unmodified url
        set req.http.X-Varnish-Origin-Url = req.url;
    }

    # Normalize request data before potentially sending things off to the
    # backend. This ensures all request types get the same information, most
    # notably POST requests getting a normalized user agent string to empower
    # adaptive designs.
    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } else if (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unknown algorithm
            unset req.http.Accept-Encoding;
        }
    }




    # We only deal with GET and HEAD by default
    # we test this here instead of inside the url base regex section
    # so we can disable caching for the entire site if needed
    if (!true || req.http.Authorization ||
        req.request !~ "^(GET|HEAD|OPTIONS)$" ||
        req.http.Cookie ~ "varnish_bypass=1") {
        if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?admin") {
            set req.backend = admin;
        }
        return (pipe);
    }

    # remove double slashes from the URL, for higher cache hit rate
    set req.url = regsuball(req.url, "([^:])//+", "\1/");

    # check if the request is for part of magento
    if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?") {
        # set this so Turpentine can see the request passed through Varnish
        set req.http.X-Turpentine-Secret-Handshake = "1";
        # use the special admin backend and pipe if it's for the admin section
        if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?admin") {
            set req.backend = admin;
            return (pipe);
        }
        if (req.http.Cookie ~ "\bcurrency=") {
            set req.http.X-Varnish-Currency = regsub(
                req.http.Cookie, ".*\bcurrency=([^;]*).*", "\1");
        }
        if (req.http.Cookie ~ "\bstore=") {
            set req.http.X-Varnish-Store = regsub(
                req.http.Cookie, ".*\bstore=([^;]*).*", "\1");
        }
        # looks like an ESI request, add some extra vars for further processing
        if (req.url ~ "/turpentine/esi/get(?:Block|FormKey)/") {
            set req.http.X-Varnish-Esi-Method = regsub(
                req.url, ".*/method/(\w+)/.*", "\1");
            set req.http.X-Varnish-Esi-Access = regsub(
                req.url, ".*/access/(\w+)/.*", "\1");

            # throw a forbidden error if debugging is off and a esi block is
            # requested by the user (does not apply to ajax blocks)
            if (req.http.X-Varnish-Esi-Method == "esi" && req.esi_level == 0 &&
                    !(false || client.ip ~ debug_acl)) {
                error 403 "External ESI requests are not allowed";
            }
        }

        # no frontend cookie was sent to us AND this is not an ESI or AJAX call
        if (req.http.Cookie !~ "frontend=" && !req.http.X-Varnish-Esi-Method) {
            if (client.ip ~ crawler_acl ||
                    req.http.User-Agent ~ "^(?:ApacheBench/.*|.*Googlebot.*|JoeDog/.*Siege.*|magespeedtest\.com|Nexcessnet_Turpentine/.*)$") {
                # it's a crawler, give it a fake cookie
                set req.http.Cookie = "frontend=crawler-session";
            } else {
                # it's a real user, make up a new session for them
                call generate_session;
            }
        }
        if (true &&
                req.url ~ ".*\.(?:css|js|jpe?g|png|gif|ico|swf)(?=\?|&|$)") {
            # don't need cookies for static assets
            unset req.http.Cookie;
            unset req.http.X-Varnish-Faked-Session;
            set req.http.X-Varnish-Static = 1;
            return (lookup);
        }
        # this doesn't need a enable_url_excludes because we can be reasonably
        # certain that cron.php at least will always be in it, so it will
        # never be empty
        if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?(?:admin|api|cron\.php|ajaxcartsuper/ajaxcart/|customer/account/create/)" ||
                # user switched stores. we pipe this instead of passing below because
                # switching stores doesn't redirect (302), just acts like a link to
                # another page (200) so the Set-Cookie header would be removed
                req.url ~ "\?.*__from_store=") {
            return (pipe);
        }
        if (true &&
                req.url ~ "(?:[?&](?:__SID|XDEBUG_PROFILE)(?=[&=]|$))") {
            # TODO: should this be pass or pipe?
            return (pass);
        }
        if (true && req.url ~ "[?&](utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|cx|ie|cof|siteurl)=") {
            # Strip out Ignored GET parameters
            set req.url = regsuball(req.url, "(?:(\?)?|&)(?:utm_source|utm_medium|utm_campaign|utm_content|utm_term|gclid|cx|ie|cof|siteurl)=[^&]+", "\1");
            set req.url = regsuball(req.url, "(?:(\?)&|\?$)", "\1");
        }

        if(false) {
            set req.http.X-Varnish-Cache-Url = req.url;
            set req.url = req.http.X-Varnish-Origin-Url;
            unset req.http.X-Varnish-Origin-Url;
        }

        # everything else checks out, try and pull from the cache
        return (lookup);
    } else {
      std.log( "This is not part of magento");
    }
    # else it's not part of magento so do default handling (doesn't help
    # things underneath magento but we can't detect that)
}

sub vcl_pipe {
    # since we're not going to do any stuff to the response we pretend the
    # request didn't pass through Varnish
    unset bereq.http.X-Turpentine-Secret-Handshake;
    set bereq.http.Connection = "close";
}

# sub vcl_pass {
#     return (pass);
# }

sub vcl_hash {
    # For static files we keep the hash simple and don't add the domain.
    # This saves memory when a static file is used on multiple domains.
    if (true && req.http.X-Varnish-Static) {
        hash_data(req.url);
        if (req.http.Accept-Encoding) {
            # make sure we give back the right encoding
            hash_data(req.http.Accept-Encoding);
        }
        return (hash);
    }

    if(false && req.http.X-Varnish-Cache-Url) {
        hash_data(req.http.X-Varnish-Cache-Url);
    } else {
        hash_data(req.url);
    }
    if (req.http.Host) {
        hash_data(req.http.Host);
    } else {
        hash_data(server.ip);
    }
    hash_data(req.http.Ssl-Offloaded);
    if (req.http.X-Normalized-User-Agent) {
        hash_data(req.http.X-Normalized-User-Agent);
    }
    if (req.http.Accept-Encoding) {
        # make sure we give back the right encoding
        hash_data(req.http.Accept-Encoding);
    }
    if (req.http.X-Varnish-Store || req.http.X-Varnish-Currency) {
        # make sure data is for the right store and currency based on the *store*
        # and *currency* cookies
        hash_data("s=" + req.http.X-Varnish-Store + "&c=" + req.http.X-Varnish-Currency);
    }

    if (req.http.X-Varnish-Esi-Access == "private" &&
            req.http.Cookie ~ "frontend=") {
        hash_data(regsub(req.http.Cookie, "^.*?frontend=([^;]*);*.*$", "\1"));


    }

    if (req.http.X-Varnish-Esi-Access == "customer_group" &&
            req.http.Cookie ~ "customer_group=") {
        hash_data(regsub(req.http.Cookie, "^.*?customer_group=([^;]*);*.*$", "\1"));
    }

    return (hash);
}

sub vcl_hit {
    # this seems to cause cache object contention issues so removed for now
    # TODO: use obj.hits % something maybe
    # if (obj.hits > 0) {
    #     set obj.ttl = obj.ttl + s;
    # }
}

# sub vcl_miss {
#     return (fetch);
# }

sub vcl_fetch {
    # set the grace period
    set req.grace = 15s;

    # Store the URL in the response object, to be able to do lurker friendly bans later
    set beresp.http.X-Varnish-Host = req.http.host;
    set beresp.http.X-Varnish-URL = req.url;

    # if it's part of magento...
    if (req.url ~ "^(/media/|/skin/|/js/|/)(?:(?:index|litespeed)\.php/)?") {
        std.log("This url is part of magento " + req.url);
        # we handle the Vary stuff ourselves for now, we'll want to actually
        # use this eventually for compatibility with downstream proxies
        # TODO: only remove the User-Agent field from this if it exists
        unset beresp.http.Vary;
        # we pretty much always want to do this
        set beresp.do_gzip = true;

        if (beresp.status != 200 && beresp.status != 404) {
            # pass anything that isn't a 200 or 404
            set beresp.ttl = 15s;
            return (hit_for_pass);
        } else {
            # if Magento sent us a Set-Cookie header, we'll put it somewhere
            # else for now
            if (beresp.http.Set-Cookie) {
                set beresp.http.X-Varnish-Set-Cookie = beresp.http.Set-Cookie;
                unset beresp.http.Set-Cookie;
            }
            # we'll set our own cache headers if we need them
            unset beresp.http.Cache-Control;
            unset beresp.http.Expires;
            unset beresp.http.Pragma;
            unset beresp.http.Cache;
            unset beresp.http.Age;

            if (beresp.http.X-Turpentine-Esi == "1") {
                set beresp.do_esi = true;
            }
            if (beresp.http.X-Turpentine-Cache == "0") {
                set beresp.ttl = 15s;
                return (hit_for_pass);
            } else {
                if (true &&
                        bereq.url ~ ".*\.(?:css|js|jpe?g|png|gif|ico|swf)(?=\?|&|$)") {
                    # it's a static asset
                    set beresp.ttl = 28800s;
                    set beresp.http.Cache-Control = "max-age=28800";
                } elseif (req.http.X-Varnish-Esi-Method) {
                    # it's a ESI request
                    if (req.http.X-Varnish-Esi-Access == "private" &&
                            req.http.Cookie ~ "frontend=") {
                        # set this header so we can ban by session from Turpentine
                        set beresp.http.X-Varnish-Session = regsub(req.http.Cookie,
                            "^.*?frontend=([^;]*);*.*$", "\1");
                    }
                    if (req.http.X-Varnish-Esi-Method == "ajax" &&
                            req.http.X-Varnish-Esi-Access == "public") {
                        set beresp.http.Cache-Control = "max-age=" + regsub(
                            req.url, ".*/ttl/(\d+)/.*", "\1");
                    }
                    set beresp.ttl = std.duration(
                        regsub(
                            req.url, ".*/ttl/(\d+)/.*", "\1s"),
                        300s);
                    if (beresp.ttl == 0s) {
                        # this is probably faster than bothering with 0 ttl
                        # cache objects
                        set beresp.ttl = 15s;
                        return (hit_for_pass);
                    }
                } else {
                    set beresp.ttl = 3600s;
                }
            }
        }
        # we've done what we need to, send to the client
        #return (deliver);
    } else {
      # else it's not part of Magento so use the default Varnish handling
      std.log("This is not part of magento " + req.url);
    }
}



sub vcl_deliver {
    if (req.http.X-Varnish-Faked-Session) {
        # need to set the set-cookie header since we just made it out of thin air
        # call generate_session_expires;
        call generate_session_expires;
        set resp.http.Set-Cookie = req.http.X-Varnish-Faked-Session +
            "; expires=" + resp.http.X-Varnish-Cookie-Expires + "; path=/";
        if (req.http.Host) {
            if (req.http.User-Agent ~ "^(?:ApacheBench/.*|.*Googlebot.*|JoeDog/.*Siege.*|magespeedtest\.com|Nexcessnet_Turpentine/.*)$") {
                # it's a crawler, no need to share cookies
                set resp.http.Set-Cookie = resp.http.Set-Cookie +
                "; domain=" + regsub(req.http.Host, ":\d+$", "");
            } else {
                # it's a real user, allow sharing of cookies between stores
                if(req.http.Host ~ "") {
                    set resp.http.Set-Cookie = resp.http.Set-Cookie +
                    "; domain=";
                } else {
                    set resp.http.Set-Cookie = resp.http.Set-Cookie +
                    "; domain=" + regsub(req.http.Host, ":\d+$", "");
                }
            }
        }
        set resp.http.Set-Cookie = resp.http.Set-Cookie + "; httponly";
        unset resp.http.X-Varnish-Cookie-Expires;
    }
    if (req.http.X-Varnish-Esi-Method == "ajax" && req.http.X-Varnish-Esi-Access == "private") {
        set resp.http.Cache-Control = "no-cache";
    }

    std.log( "Caller ip is " + client.ip);
    if (true || client.ip ~ debug_acl) {
        # debugging is on, give some extra info
        set resp.http.X-Varnish-Hits = obj.hits;
        set resp.http.X-Varnish-Esi-Method = req.http.X-Varnish-Esi-Method;
        set resp.http.X-Varnish-Esi-Access = req.http.X-Varnish-Esi-Access;
        set resp.http.X-Varnish-Currency = req.http.X-Varnish-Currency;
        set resp.http.X-Varnish-Store = req.http.X-Varnish-Store;
    } else {
        # remove Varnish fingerprints
        unset resp.http.X-Varnish;
        unset resp.http.Via;
        unset resp.http.X-Powered-By;
        unset resp.http.Server;
        unset resp.http.X-Turpentine-Cache;
        unset resp.http.X-Turpentine-Esi;
        unset resp.http.X-Turpentine-Flush-Events;
        unset resp.http.X-Turpentine-Block;
        unset resp.http.X-Varnish-Session;
        unset resp.http.X-Varnish-Host;
        unset resp.http.X-Varnish-URL;
        # this header indicates the session that originally generated a cached
        # page. it *must* not be sent to a client in production with lax
        # session validation or that session can be hijacked
        unset resp.http.X-Varnish-Set-Cookie;
    }
}

## Custom VCL Logic

## START TEMPLATE
acl purge {
	"localhost";
  "172.17.0.1";
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
			error 405 "Not allowed: " + client.ip;
		}
		return (lookup);
	}

	if (req.http.Cache-Control ~ "no-cache" && client.ip ~ purge) {
		set req.hash_always_miss = true;
	}

	if (req.request == "BAN") {
		if(!client.ip ~ purge) {
			error 405 "Not allowed." + client.ip;
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
				set req.http.Cookie = regsuball(req.http.Cookie, ";(ow_cookie_notice|PHPSESSID|NO_CACHE|wordpress_logged_in_)=", "; \1=");
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
