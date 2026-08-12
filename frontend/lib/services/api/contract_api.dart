import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_api.dart';

class ContractApi {
  static Future<List<dynamic>> fetchContracts(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createContract(String token, Map<String, dynamic> contractData) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode(contractData),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateContract(String token, String contractId, Map<String, dynamic> contractData) async {
    final response = await http.put(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId'),
      headers: BaseApi.getHeaders(token),
      body: jsonEncode(contractData),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Generates (or idempotently re-fetches) the buyer's booking-deposit KHQR
  /// for an accepted (PENDING_DEPOSIT) contract.
  static Future<Map<String, dynamic>> generateDepositKhqr(String token, String contractId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId/deposit/khqr'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Re-verifies the deposit KHQR against Bakong and, only on a confirmed
  /// "paid", activates the contract. Returns `{'status': 'paid'|'unpaid'|'unavailable'}`.
  static Future<Map<String, dynamic>> confirmDepositKhqr(String token, String contractId, String md5Hash) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId/deposit/khqr/$md5Hash/confirm'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Admin-only. Every contract still awaiting deposit confirmation — the
  /// queue for the manual-confirm fallback used when automatic Bakong
  /// verification can't run.
  static Future<List<dynamic>> fetchPendingDeposits(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/admin/pending-deposits'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  /// Admin-only manual override marking a contract deposit as paid — a
  /// fallback for when automatic Bakong verification isn't available.
  static Future<Map<String, dynamic>> confirmDepositAsAdmin(String token, String contractId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId/deposit/confirm-payment'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Generates (or idempotently re-fetches) the buyer's final-balance KHQR
  /// once the seller has requested it (PENDING_FINAL_PAYMENT).
  static Future<Map<String, dynamic>> generateFinalPaymentKhqr(String token, String contractId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId/final-payment/khqr'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Re-verifies the final-payment KHQR against Bakong and, only on a
  /// confirmed "paid", completes the contract. Returns
  /// `{'status': 'paid'|'unpaid'|'unavailable'}`.
  static Future<Map<String, dynamic>> confirmFinalPaymentKhqr(String token, String contractId, String md5Hash) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId/final-payment/khqr/$md5Hash/confirm'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }

  /// Admin-only. Every contract still awaiting final-payment confirmation.
  static Future<List<dynamic>> fetchPendingFinalPayments(String token) async {
    final response = await http.get(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/admin/pending-final-payments'),
      headers: BaseApi.getHeaders(token),
    );
    return BaseApi.handleResponse(response) as List<dynamic>;
  }

  /// Admin-only manual override marking a contract's final payment as paid.
  static Future<Map<String, dynamic>> confirmFinalPaymentAsAdmin(String token, String contractId) async {
    final response = await http.post(
      Uri.parse('${BaseApi.baseUrl}/api/${BaseApi.version}/contracts/$contractId/final-payment/confirm-payment'),
      headers: BaseApi.getHeaders(token, json: false),
    );
    return BaseApi.handleResponse(response) as Map<String, dynamic>;
  }
}
