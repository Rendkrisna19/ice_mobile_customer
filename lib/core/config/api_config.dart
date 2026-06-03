import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String serverUrl = "https://linen-deer-529188.hostingersite.com";
  static String get domain => serverUrl;

  static String get baseUrl => "$domain/api/v1";

  static String get profileUpdate => "$baseUrl/auth/profile/update";
  static String get profilePhotoUpdate => "$baseUrl/auth/profile/photo";

  static String get login => "$baseUrl/auth/login";
  static String get register => "$baseUrl/auth/register";
  static String get user => "$baseUrl/auth/user";
  static String get deleteAccount => "$baseUrl/auth/delete-account";

  static String get outlets => "$baseUrl/outlets";

  static String get products => "$baseUrl/products";

  static String get customerOrders => "$baseUrl/customer/orders";
}