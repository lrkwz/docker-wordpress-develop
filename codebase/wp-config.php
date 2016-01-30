<?php
/**
 * The base configurations of the WordPress.
 *
 * This file has the following configurations: MySQL settings, Table Prefix,
 * Secret Keys, and ABSPATH. You can find more information by visiting
 * {@link http://codex.wordpress.org/Editing_wp-config.php Editing wp-config.php}
 * Codex page. You can get the MySQL settings from your web host.
 *
 * This file is used by the wp-config.php creation script during the
 * installation. You don't have to use the web site, you can just copy this file
 * to "wp-config.php" and fill in the values.
 *
 * @package WordPress
 */

include('wp-config-local.php');

/**
 * creare il file wp-config-local.php per specificare i dati di connessione al db
 */
/*
define('DB_NAME', 'database_name_here');
define('DB_USER', 'username_here');
define('DB_PASSWORD', 'password_here');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
*/

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         'WJw_{+J{#bW^[Wo-t}a^BHT*o1K}%]e]P9?-gn8d>2~NEU8J7a|km@ocq0L-6>iJ');
define('SECURE_AUTH_KEY',  '-F^pi=+nVUc!`v{K(a2MQ&$4VBajmY-h6uMIR1YEi{Wsxtj@+t.`#KYdah2/C~eI');
define('LOGGED_IN_KEY',    'v^D^56rtpJ@B6UBvqK_M%[N9VEnzs`u<iw[2tvX6e=hO#j%!!mxgvNb?| 8r$.*3');
define('NONCE_KEY',        'a&n%eZ)e-c(c$<sP$umcIE0r^@qXd?kH;,TAs2F,U0w+8 =J}dYs9kzbpJ-<>3||');
define('AUTH_SALT',        'sK{}q1V<x$g8|8X0poE,/~is)L-CHUnj}B^pC;dgPS7Qp.OqvwxF+.h)Z-Sw~hHp');
define('SECURE_AUTH_SALT', 'IJj7K!A#PvN:YQntoS1MO<{am|8[bvD[l^38+L@NBSF((vyM4{Zk2^@aO-K^Z2@-');
define('LOGGED_IN_SALT',   'I~*%]HO^IN5W& z!&-N0%(APZ8c>jFbMPX!j!Qfz |FoOe{<IsqW.Hz*{@J;WyqF');
define('NONCE_SALT',       'L5pDn(-0-*VD{l(XW/NAYti>x;gX[L6O@s{zxWP,6+Ho9Q^5kW|*vEQSBtHjKu26');

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each a unique
 * prefix. Only numbers, letters, and underscores please!
 *
 */
$table_prefix  = 'wp_';

define('WP_HOME', 'http://' . $_SERVER['HTTP_HOST'] );
define('WP_SITEURL', 'http://' . $_SERVER['HTTP_HOST'] . '/wp' );
define('WP_CONTENT_DIR', dirname(__FILE__) . '/wp-content');
define('WP_CONTENT_URL', WP_HOME . '/wp-content');

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 */
define('WP_DEBUG', false);

/* That's all, stop editing! Happy blogging. */

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
