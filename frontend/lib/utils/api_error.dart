import '../models/state/base_app_state.dart';

/// Maps a backend error CODE (e.g. `"ORDER_NOT_FOUND"`) to its translation
/// key. The backend intentionally sends machine-readable codes, not prose —
/// see `backend/app/core/errors.py` — so every code that can reach the
/// client needs an entry here. Add to this map (and to both language blocks
/// in `translations.dart`) whenever a new `errors.py` constant is raised
/// somewhere a user can trigger it.
const Map<String, String> _apiErrorTranslationKeys = {
  // Auth
  'INCORRECT_CREDENTIALS': 'incorrect_credentials_error',
  'ACCOUNT_LOCKED': 'account_locked_error',
  'INACTIVE_USER': 'inactive_user_error',
  'USER_NOT_FOUND': 'user_not_found_error',
  'COULD_NOT_VALIDATE_CREDENTIALS': 'session_expired_error',
  'NOT_AUTHENTICATED': 'session_expired_error',
  'INVALID_EMAIL_FORMAT': 'invalid_email_format_error',
  'PASSWORD_MIN_8_CHARACTERS': 'password_min_length_error',
  'EMAIL_ALREADY_EXISTS': 'email_already_exists_error',
  'PHONE_NUMBER_ALREADY_EXISTS': 'phone_already_exists_error',
  'INVALID_OR_EXPIRED_CODE': 'invalid_or_expired_code_error',
  'NO_EMAIL_ON_ACCOUNT': 'no_email_on_account_error',

  // Generic
  'INTERNAL_SERVER_ERROR': 'generic_server_error',
  'DATABASE_ERROR': 'generic_server_error',
  'VALIDATION_ERROR': 'generic_server_error',
  'NOT_AUTHORIZED': 'not_authorized_error',

  // Not-found / model errors
  'CATEGORY_NOT_FOUND': 'category_not_found_error',
  'PRODUCT_NOT_FOUND': 'product_unavailable',
  'ORDER_NOT_FOUND': 'order_not_found_error',
  'CONTRACT_NOT_FOUND': 'contract_not_found_error',
  'DELIVERY_NOT_FOUND': 'delivery_not_found_error',
  'NOTIFICATION_NOT_FOUND': 'notification_not_found_error',
  'FORUM_POST_NOT_FOUND': 'forum_post_not_found_error',
  'CONTENT_REPORT_NOT_FOUND': 'content_report_not_found_error',
  'DISPUTE_NOT_FOUND': 'dispute_not_found_error',
  'ADDRESS_CHANGE_REQUEST_NOT_FOUND': 'address_request_not_found_error',
  'COOPERATIVE_MEMBER_NOT_FOUND': 'cooperative_member_not_found_error',

  // Orders / checkout
  'CANNOT_ORDER_OWN_PRODUCT': 'cannot_order_own_product',
  'INSUFFICIENT_STOCK': 'exceeds_stock',
  'DELIVERY_LOCATION_REQUIRED': 'delivery_location_required',
  'ORDER_CANNOT_BE_CANCELLED': 'order_cannot_be_cancelled_error',
  'ORDER_ALREADY_PAID': 'order_already_paid_error',
  'MULTIPLE_CURRENCIES_IN_ORDER': 'multiple_currencies_in_order_error',
  'MULTIPLE_SELLERS_IN_ORDER': 'multiple_sellers_in_order_error',
  'NO_ITEMS_IN_ORDER': 'no_items_in_order_error',
  'INVALID_ORDER_STATUS_TRANSITION': 'invalid_order_status_transition_error',
  'PAYMENT_NOT_CONFIRMED': 'payment_not_confirmed_error',

  // Contracts
  'CANNOT_MODIFY_ITEMS_AFTER_DRAFT': 'error_cannot_modify_after_draft',
  'CONTRACT_PRODUCT_OWNER_MISMATCH': 'error_contract_product_owner_mismatch',
  'START_DATE_MUST_BE_IN_FUTURE': 'start_date_future_error',
  'END_DATE_MUST_BE_AFTER_START_DATE': 'end_date_after_start_error',
  'ONLY_SELLER_CAN_ACTIVATE_CONTRACT': 'error_only_seller_can_activate',
  'CONTRACT_ALREADY_RESOLVED': 'error_contract_already_resolved',

  // Reviews
  'ORDER_NOT_DELIVERED': 'error_order_not_delivered',
  'ORDER_ALREADY_REVIEWED': 'error_order_already_reviewed',

  // Disputes
  'DISPUTE_ALREADY_OPEN': 'error_dispute_already_open',
  'DISPUTE_ALREADY_RESOLVED': 'dispute_already_resolved_error',
  'INVALID_DISPUTE_STATUS': 'invalid_dispute_status_error',

  // Chat
  'CHAT_SENDER_CANNOT_BE_RECEIVER': 'chat_cannot_message_self_error',

  // Address change requests
  'ADDRESS_CHANGE_REQUEST_ALREADY_RESOLVED': 'address_request_already_resolved_error',
  'ADDRESS_CHANGE_REQUEST_ALREADY_PENDING': 'address_request_already_pending_error',

  // Cooperatives
  'COOPERATIVE_MEMBER_ALREADY_EXISTS': 'cooperative_member_already_exists_error',
  'CANNOT_INVITE_SELF': 'cannot_invite_self_error',

  // Products
  'PRODUCT_HAS_RELATED_INFO': 'product_has_related_info',
};

/// Extracts the backend error code out of an exception's string form.
/// `BaseApi.handleResponse` throws `Exception(code)`, and Dart's default
/// `toString()` on that prepends `"Exception: "` — strip it so lookups
/// against [_apiErrorTranslationKeys] match.
String extractApiErrorCode(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();

/// Translates an already-extracted backend error code (no "Exception: "
/// prefix) to a message safe to show a user. Unrecognized codes fall back
/// to a generic translated message rather than leaking the raw string.
String translateErrorCode(BaseAppState state, String code) {
  final key = _apiErrorTranslationKeys[code];
  return state.translate(key ?? 'generic_error');
}

/// Translates any error caught from an API call into a message safe to show
/// a user — never the raw backend code, and never a bare "Exception: ...".
String friendlyApiError(BaseAppState state, Object error) {
  return translateErrorCode(state, extractApiErrorCode(error));
}
