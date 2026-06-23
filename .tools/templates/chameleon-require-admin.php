<?php
/**
 * Require (Chameleon) Chameleon Admin before this plugin can activate or run.
 *
 * Canonical copy: wordpress_plugins/.tools/templates/chameleon-require-admin.php
 * Deploy a copy as <plugin>/includes/chameleon-require-admin.php (or next to the main plugin file).
 *
 * @package Chameleon_Require_Admin
 */

defined( 'ABSPATH' ) || exit;

$chameleon_require_admin_template_dir = dirname( __FILE__ );
$chameleon_upgrader_ajax_bootstrap   = $chameleon_require_admin_template_dir . '/chameleon-upgrader-ajax.php';
if ( ! is_readable( $chameleon_upgrader_ajax_bootstrap ) ) {
	$chameleon_wp_root = $chameleon_require_admin_template_dir;
	for ( $i = 0; $i < 8; $i++ ) {
		$chameleon_wp_root = dirname( $chameleon_wp_root );
		if ( basename( $chameleon_wp_root ) === 'wordpress_plugins' ) {
			$chameleon_upgrader_ajax_bootstrap = $chameleon_wp_root . '/.tools/templates/chameleon-upgrader-ajax.php';
			break;
		}
	}
}
if ( is_readable( $chameleon_upgrader_ajax_bootstrap ) ) {
	require_once $chameleon_upgrader_ajax_bootstrap;
}

if ( ! function_exists( 'chameleon_plugin_is_admin_active' ) ) {

	/**
	 * Whether chameleon-admin is installed and active.
	 */
	function chameleon_plugin_is_admin_active(): bool {
		if ( ! function_exists( 'is_plugin_active' ) ) {
			require_once ABSPATH . 'wp-admin/includes/plugin.php';
		}

		return is_plugin_active( 'chameleon-admin/chameleon-admin.php' );
	}

	/**
	 * Block activation when Chameleon Admin is missing (call from activation hook).
	 *
	 * @param string $plugin_main_file Main plugin file path (__FILE__).
	 * @param string $text_domain      Plugin text domain for translated messages.
	 */
	function chameleon_plugin_block_activate_without_admin( string $plugin_main_file, string $text_domain ): void {
		if ( function_exists( 'chameleon_is_upgrader_ajax_request' ) && chameleon_is_upgrader_ajax_request() ) {
			return;
		}

		if ( chameleon_plugin_is_admin_active() ) {
			return;
		}

		if ( ! function_exists( 'deactivate_plugins' ) ) {
			require_once ABSPATH . 'wp-admin/includes/plugin.php';
		}

		deactivate_plugins( plugin_basename( $plugin_main_file ) );

		wp_die(
			esc_html__(
				'This plugin requires Chameleon Admin to be installed and active. Install and activate Chameleon Admin first, then try again.',
				$text_domain
			),
			esc_html__( 'Plugin activation blocked', $text_domain ),
			array( 'back_link' => true )
		);
	}

	/**
	 * Register activation guard and runtime deactivation if Admin is removed.
	 *
	 * @param string $plugin_main_file Main plugin file path (__FILE__).
	 * @param string $text_domain      Plugin text domain.
	 */
	function chameleon_plugin_require_admin_bootstrap( string $plugin_main_file, string $text_domain ): void {
		register_activation_hook(
			$plugin_main_file,
			static function () use ( $plugin_main_file, $text_domain ): void {
				chameleon_plugin_block_activate_without_admin( $plugin_main_file, $text_domain );
			}
		);

		add_action(
			'plugins_loaded',
			static function () use ( $plugin_main_file, $text_domain ): void {
				if ( function_exists( 'chameleon_is_upgrader_ajax_request' ) && chameleon_is_upgrader_ajax_request() ) {
					return;
				}

				if ( chameleon_plugin_is_admin_active() ) {
					return;
				}

				if ( ! function_exists( 'deactivate_plugins' ) ) {
					require_once ABSPATH . 'wp-admin/includes/plugin.php';
				}

				if ( is_admin() ) {
					add_action(
						'admin_notices',
						static function () use ( $text_domain ): void {
							printf(
								'<div class="notice notice-error"><p>%s</p></div>',
								esc_html__(
									'Chameleon Admin is required. This plugin has been deactivated.',
									$text_domain
								)
							);
						}
					);
				}

				deactivate_plugins( plugin_basename( $plugin_main_file ) );
			},
			1
		);
	}
}
