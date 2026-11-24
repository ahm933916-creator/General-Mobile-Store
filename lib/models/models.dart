class Product {
  final int? id;
  final String code;
  final String name;
  final int categoryId;
  final String? imagePath;
  final String? barcodeImagePath; // حقل مسار صورة الباركود المخصص
  final String status;
  final int quantity;
  final int purchasedQuantity;
  final String currencyCode;
  final double purchasePrice;
  final double sellingPrice;
  final bool isForSale;
  final bool isForRent;
  final double rentalPrice;
  final String rentalStatus;

  Product({
    this.id,
    required this.code,
    required this.name,
    required this.categoryId,
    this.imagePath,
    this.barcodeImagePath,
    required this.status,
    required this.quantity,
    this.purchasedQuantity = 0,
    this.currencyCode = 'SYP',
    required this.purchasePrice,
    required this.sellingPrice,
    this.isForSale = true,
    this.isForRent = false,
    this.rentalPrice = 0.0,
    this.rentalStatus = 'متاح',
  });

  // تحويل الكود إلى خريطة (Map) لتخزينه في قاعدة البيانات SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'categoryId': categoryId,
      'imagePath': imagePath,
      'barcodeImagePath': barcodeImagePath,
      'status': status,
      'quantity': quantity,
      'purchasedQuantity': purchasedQuantity,
      'currencyCode': currencyCode,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'isForSale': isForSale ? 1 : 0,
      'isForRent': isForRent ? 1 : 0,
      'rentalPrice': rentalPrice,
      'rentalStatus': rentalStatus,
    };
  }

  // إنشاء كود المنتج من بيانات قاعدة البيانات SQLite
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      categoryId: map['categoryId'] ?? 0,
      imagePath: map['imagePath'],
      barcodeImagePath: map['barcodeImagePath'],
      status: map['status'] ?? 'متوفر',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      purchasedQuantity: (map['purchasedQuantity'] as num?)?.toInt() ?? 0,
      currencyCode: map['currencyCode']?.toString() ?? 'SYP',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      isForSale: (map['isForSale'] as num?)?.toInt() != 0,
      isForRent: (map['isForRent'] as num?)?.toInt() == 1,
      rentalPrice: (map['rentalPrice'] as num?)?.toDouble() ?? 0.0,
      rentalStatus: map['rentalStatus']?.toString() ?? 'متاح',
    );
  }
}

// نموذج المستخدم (AppUser)
class AppUser {
  final int? id;
  final String code;
  final String name;
  final String phone;
  final String? address;
  final String password;

  AppUser({
    this.id,
    required this.code,
    required this.name,
    required this.phone,
    this.address,
    this.password = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'phone': phone,
      'address': address,
      'password': password,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'],
      password: map['password']?.toString() ?? '',
    );
  }
}

// نموذج التصنيف (Category)
class Category {
  final int? id;
  final String? code;
  final String name;

  Category({
    this.id,
    this.code,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      code: map['code'],
      name: map['name'] ?? '',
    );
  }
}

class Supplier {
  final int? id;
  final String code;
  final String name;
  final String phone;
  final String? address;

  Supplier({this.id, required this.code, required this.name, required this.phone, this.address});

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'phone': phone,
        'address': address,
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'],
        code: map['code']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        phone: map['phone']?.toString() ?? '',
        address: map['address']?.toString(),
      );
}

// نموذج المصروفات (Expense)
class Expense {
  final int? id;
  final String type;
  final String date;
  final double cost;
  final String currencyCode;
  final double exchangeRate;

  Expense({
    this.id,
    required this.type,
    required this.date,
    required this.cost,
    this.currencyCode = 'SYP',
    this.exchangeRate = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'date': date,
      'cost': cost,
      'currencyCode': currencyCode,
      'exchangeRate': exchangeRate,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      type: map['type'] ?? '',
      date: map['date'] ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      currencyCode: map['currencyCode']?.toString() ?? 'SYP',
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble() ?? 1,
    );
  }
}

// نموذج نوع المصروف (ExpenseType)
class ExpenseType {
  final int? id;
  final String name;

  ExpenseType({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory ExpenseType.fromMap(Map<String, dynamic> map) {
    return ExpenseType(
      id: map['id'],
      name: map['name'] ?? '',
    );
  }
}
