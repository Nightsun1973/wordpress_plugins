<?php
/**
 * Require ERP Connector before this plugin can activate or run.
 *
 * Canonical copy: wordpress_plugins/.tools/templates/chameleon-require-erp.php
 * Deploy a copy as <plugin>/includes/chameleon-require-erp.php (or next to the main plugin file).
 *
 * @package Chameleon_Require_Erp
 */

defined( 'ABSPATH' ) || exit;

if ( ! function_exists( 'chameleon_plugin_erp_connector_basename' ) ) {

	/**
	 * Installed ERP Connector main file relative to wp-content/plugins/.
	 */
	function chameleon_plugin_erp_connector_basename(): string {
		return 'erp-connector/erp-connector.php';
	}
}

if ( ! function_exists( 'chameleon_plugin_is_erp_connector_satisfied' ) ) {

	/**
	 * Whether ERP Connector is present, active, and connected.
	 */
	function chameleon_plugin_is_erp_connector_satisfied(): bool {
		$basename  = chameleon_plugin_erp_connector_basename();
		$main_file = WP_PLUGIN_DIR . '/' . $basename;

		if ( ! is_readable( $main_file ) ) {
			return false;
		}

		if ( ! function_exists( 'erp_connector' ) ) {
			if ( ! function_exists( 'is_plugin_active' ) ) {
				require_once ABSPATH . 'wp-admin/includes/plugin.php';
			}

			return is_plugin_active( $basename );
		}

		try {
			$connector = erp_connector();

			return is_object( $connector )
				&& method_exists( $connector, 'is_connected' )
				&& (bool) $connector->is_connected();
		} catch ( Throwable $t ) {
			return false;
		}
	}
}

if ( ! function_exists( 'chameleon_plugin_block_activate_without_erp' ) ) {

	/**
	 * Block activation when ERP Connector is missing or not connected.
	 *
	 * @param string $plugin_main_file Main plugin file path (__FILE__).
	 * @param string $text_domain      Plugin text domain for translated messages.
	 */
	function chameleon_plugin_block_activate_without_erp( string $plugin_main_file, string $text_domain ): void {
		if ( ! function_exists( 'deactivate_plugins' ) ) {
			require_once ABSPATH . 'wp-admin/includes/plugin.php';
		}

		$basename  = chameleon_plugin_erp_connector_basename();
		$main_file = WP_PLUGIN_DIR . '/' . $basename;

		if ( ! is_readable( $main_file ) ) {
			deactivate_plugins( plugin_basename( $plugin_main_file ) );
			wp_die(
				esc_html__(
					'This plugin requires ERP Connector to be installed. Install and activate ERP Connector first, then try again.',
					$text_domain
				),
				esc_html__( 'Plugin dependency missing', $text_domain ),
				array( 'back_link' => true )
			);
		}

		if ( ! function_exists( 'erp_connector' ) ) {
			deactivate_plugins( plugin_basename( $plugin_main_file ) );
			wp_die(
				esc_html__(
					'This plugin requires ERP Connector to be active. Activate ERP Connector first, then try again.',
					$text_domain
				),
				esc_html__( 'Plugin dependency missing', $text_domain ),
				array( 'back_link' => true )
			);
		}

		if ( ! chameleon_plugin_is_erp_connector_satisfied() ) {
			deactivate_plugins( plugin_basename( $plugin_main_file ) );
			wp_die(
				esc_html__(
					'This plugin requires ERP Connector to be configured and connected. Open Chameleon → ERP Connector, save PostgreSQL settings, and test the connection before activating this plugin.',
					$text_domain
				),
				esc_html__( 'ERP Connector not connected', $text_domain ),
				array( 'back_link' => true )
			);
		}
	}
}

if ( ! function_exists( 'chameleon_plugin_require_erp_bootstrap' ) ) {

	/**
	 * Register activation guard and runtime deactivation when ERP Connector is removed or disconnected.
	 *
	 * @param string $plugin_main_file Main plugin file path (__FILE__).
	 * @param string $text_domain      Plugin text domain.
	 */
	function chameleon_plugin_require_erp_bootstrap( string $plugin_main_file, string $text_domain ): void {
		register_activation_hook(
			$plugin_main_file,
			static function () use ( $plugin_main_file, $text_domain ): void {
				chameleon_plugin_block_activate_without_erp( $plugin_main_file, $text_domain );
			}
		);

		add_action(
			'plugins_loaded',
			static function () use ( $plugin_main_file, $text_domain ): void {
				if ( chameleon_plugin_is_erp_connector_satisfied() ) {
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
									'ERP Connector is required and must be connected. This plugin has been deactivated.',
									$text_domain
								)
							);
						}
					);
				}

				deactivate_plugins( plugin_basename( $plugin_main_file ) );
			},
			20
		);
	}
}
