
import '../../repositories/customer_repository.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/order_repository.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../config/constants.dart';

class TestDataSeeder {
  static Future<void> seedTestData() async {
    final customerRepo = CustomerRepository();
    final serviceRepo = ServiceRepository();
    final orderRepo = OrderRepository();
    
    // Check if data already exists
    final existingCustomers = await customerRepo.getAll();
    if (existingCustomers.isNotEmpty) {
      // print('Test data already exists');
      return;
    }
    
    // print('Seeding test data...');
    
    // Create test customers
    final customer1Id = await customerRepo.create(Customer(
      name: 'Nguyễn Văn A',
      phone: '0901234567',
      address: '123 Đường ABC, Quận 1, TP.HCM',
      email: 'nguyenvana@email.com',
    ));
    
    final customer2Id = await customerRepo.create(Customer(
      name: 'Trần Thị B',
      phone: '0907654321',
      address: '456 Đường XYZ, Quận 2, TP.HCM',
    ));
    
    final customer3Id = await customerRepo.create(Customer(
      name: 'Lê Văn C',
      phone: '0903456789',
      address: '789 Đường DEF, Quận 3, TP.HCM',
      email: 'levanc@email.com',
      notes: 'Khách hàng VIP',
    ));
    
    // Get services
    final services = await serviceRepo.getAll();
    if (services.isEmpty) {
      // print('No services found');
      return;
    }
    
    // Get admin user (should be ID 1)
    final employeeId = 1;
    
    // Create test orders
    // Order 1: Received status
    await orderRepo.createOrderWithCode(
      Order(
        orderCode: '',
        barcode: '',
        customerId: customer1Id,
        employeeId: employeeId,
        status: AppConstants.orderStatusReceived,
        totalAmount: 65000,
        paidAmount: 0,
        receivedDate: DateTime.now(),
        deliveryDate: DateTime.now().add(const Duration(days: 2)),
      ),
      [
        OrderItem(
          orderId: 0,
          serviceId: services[0].id!,
          quantity: 2,
          unitPrice: services[0].price,
          subtotal: services[0].price * 2,
        ),
        OrderItem(
          orderId: 0,
          serviceId: services[2].id!,
          quantity: 3,
          unitPrice: services[2].price,
          subtotal: services[2].price * 3,
        ),
      ],
    );
    
    // Order 2: Washing status
    await orderRepo.createOrderWithCode(
      Order(
        orderCode: '',
        barcode: '',
        customerId: customer2Id,
        employeeId: employeeId,
        status: AppConstants.orderStatusWashing,
        totalAmount: 90000,
        paidAmount: 50000,
        paymentMethod: AppConstants.paymentCash,
        receivedDate: DateTime.now().subtract(const Duration(days: 1)),
        deliveryDate: DateTime.now().add(const Duration(days: 1)),
      ),
      [
        OrderItem(
          orderId: 0,
          serviceId: services[1].id!,
          quantity: 3,
          unitPrice: services[1].price,
          subtotal: services[1].price * 3,
        ),
        OrderItem(
          orderId: 0,
          serviceId: services[3].id!,
          quantity: 1,
          unitPrice: services[3].price,
          subtotal: services[3].price,
        ),
      ],
    );
    
    // Order 3: Washed status
    await orderRepo.createOrderWithCode(
      Order(
        orderCode: '',
        barcode: '',
        customerId: customer3Id,
        employeeId: employeeId,
        status: AppConstants.orderStatusWashed,
        totalAmount: 30000,
        paidAmount: 30000,
        paymentMethod: AppConstants.paymentBankTransfer,
        receivedDate: DateTime.now().subtract(const Duration(days: 2)),
        deliveryDate: DateTime.now(),
      ),
      [
        OrderItem(
          orderId: 0,
          serviceId: services[4].id!,
          quantity: 1,
          unitPrice: services[4].price,
          subtotal: services[4].price,
        ),
      ],
    );
    
    // Order 4: Delivered status
    await orderRepo.createOrderWithCode(
      Order(
        orderCode: '',
        barcode: '',
        customerId: customer1Id,
        employeeId: employeeId,
        status: AppConstants.orderStatusDelivered,
        totalAmount: 40000,
        paidAmount: 40000,
        paymentMethod: AppConstants.paymentCash,
        receivedDate: DateTime.now().subtract(const Duration(days: 5)),
        deliveryDate: DateTime.now().subtract(const Duration(days: 3)),
        completedDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      [
        OrderItem(
          orderId: 0,
          serviceId: services[0].id!,
          quantity: 2,
          unitPrice: services[0].price,
          subtotal: services[0].price * 2,
        ),
        OrderItem(
          orderId: 0,
          serviceId: services[2].id!,
          quantity: 1,
          unitPrice: services[2].price,
          subtotal: services[2].price,
        ),
      ],
    );
    
    // print('Test data seeded successfully!');
    // print('Created ${3} customers');
    // print('Created ${4} orders');
  }
}
