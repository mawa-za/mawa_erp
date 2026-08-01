import '../../service_orders/screens/service_order_screen.dart';

@Deprecated('Use ServiceOrderScreen from features/service_orders')
class AppointmentServiceOrderScreen extends ServiceOrderScreen {
  const AppointmentServiceOrderScreen({
    super.key,
    required super.serviceOrderId,
  });
}
