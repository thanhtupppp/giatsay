class AppConstants {
  // App Info
  static const String appName = 'Laundry Management';
  static const String appVersion = '1.0.0';

  // Database
  static const String dbName = 'laundry_management.db';
  static const int dbVersion = 6;

  // Order Status
  static const String orderStatusReceived = 'received';
  static const String orderStatusWashing = 'washing';
  static const String orderStatusWashed = 'washed';
  static const String orderStatusDelivered = 'delivered';

  static const List<String> orderStatuses = [
    orderStatusReceived,
    orderStatusWashing,
    orderStatusWashed,
    orderStatusDelivered,
  ];

  static const Map<String, String> orderStatusLabels = {
    orderStatusReceived: 'Mới nhận',
    orderStatusWashing: 'Đang giặt',
    orderStatusWashed: 'Đã giặt xong',
    orderStatusDelivered: 'Đã giao',
  };

  // User Roles
  static const String roleAdmin = 'admin';
  static const String roleManager = 'manager';
  static const String roleEmployee = 'employee';

  static const List<String> userRoles = [roleAdmin, roleManager, roleEmployee];

  static const Map<String, String> roleLabels = {
    roleAdmin: 'Quản trị viên',
    roleManager: 'Quản lý',
    roleEmployee: 'Nhân viên',
  };

  // Payment Methods
  static const String paymentCash = 'cash';
  static const String paymentBankTransfer = 'bank_transfer';
  static const String paymentMomo = 'momo';
  static const String paymentZaloPay = 'zalopay';

  static const List<String> paymentMethods = [
    paymentCash,
    paymentBankTransfer,
    paymentMomo,
    paymentZaloPay,
  ];

  static const Map<String, String> paymentMethodLabels = {
    paymentCash: 'Tiền mặt',
    paymentBankTransfer: 'Chuyển khoản',
    paymentMomo: 'MoMo',
    paymentZaloPay: 'ZaloPay',
  };

  // Transaction Types
  static const String transactionIncome = 'income';
  static const String transactionExpense = 'expense';

  static const Map<String, String> transactionTypeLabels = {
    transactionIncome: 'Thu',
    transactionExpense: 'Chi',
  };

  // Service Units
  static const String unitKg = 'kg';
  static const String unitItem = 'item';
  static const String unitSet = 'set';

  static const List<String> serviceUnits = [unitKg, unitItem, unitSet];

  static const Map<String, String> serviceUnitLabels = {
    unitKg: 'Kg',
    unitItem: 'Món',
    unitSet: 'Bộ',
  };

  // Asset Conditions
  static const String conditionGood = 'good';
  static const String conditionFair = 'fair';
  static const String conditionPoor = 'poor';

  static const List<String> assetConditions = [
    conditionGood,
    conditionFair,
    conditionPoor,
  ];

  static const Map<String, String> assetConditionLabels = {
    conditionGood: 'Tốt',
    conditionFair: 'Khá',
    conditionPoor: 'Kém',
  };

  // Barcode Settings
  static const int barcodeWidth = 3;
  static const int barcodeHeight = 80;
  static const double labelWidth = 50; // mm
  static const double labelHeight = 30; // mm

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';

  // Pagination
  static const int itemsPerPage = 20;

  // Storage Keys
  static const String keyUserId = 'user_id';
  static const String keyUsername = 'username';
  static const String keyUserRole = 'user_role';
  static const String keyAutoBackup = 'auto_backup';
  static const String keyLastBackup = 'last_backup';
}
