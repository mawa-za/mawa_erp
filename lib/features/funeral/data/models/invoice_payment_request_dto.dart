import 'funeral_enums.dart';

class InvoicePaymentRequestDto {
  final int amountCents;
  final PaymentMethod paymentMethod;
  final String reference;

  InvoicePaymentRequestDto({
    required this.amountCents,
    required this.paymentMethod,
    required this.reference,
  });

  Map<String, dynamic> toJson() {
    return {
      'amountCents': amountCents,
      'paymentMethod': paymentMethod.name,
      'reference': reference,
    };
  }

  factory InvoicePaymentRequestDto.fromJson(Map<String, dynamic> json) {
    return InvoicePaymentRequestDto(
      amountCents: json['amountCents'] as int? ?? 0,
      paymentMethod: PaymentMethod.parse(json['paymentMethod']?.toString()),
      reference: json['reference']?.toString() ?? '',
    );
  }
}
