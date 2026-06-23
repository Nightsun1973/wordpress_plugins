<?php
/**
 * Detect WordPress core plugin upgrader AJAX (update-plugin, etc.).
 *
 * Canonical copy: wordpress_plugins/.tools/templates/chameleon-upgrader-ajax.php
 *
 * @package Chameleon_Upgrader_Ajax
 */

defined( 'ABSPATH' ) || exit;

if ( ! function_exists( 'chameleon_is_upgrader_ajax_request' ) ) {

	/**
	 * Whether the current request is a core wp-admin plugin upgrader AJAX action.
	 */
	function chameleon_is_upgrader_ajax_request(): bool {
		if ( ! wp_doing_ajax() ) {
			return false;
		}

		$action = isset( $_REQUEST['action'] ) ? sanitize_key( wp_unslash( $_REQUEST['action'] ) ) : '';

		return in_array(
			$action,
			array(
				'update-plugin',
				'install-plugin',
				'upload-plugin',
			),
			true
		);
	}
}
