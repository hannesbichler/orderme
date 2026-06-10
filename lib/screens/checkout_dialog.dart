import 'package:flutter/material.dart';

import '../models/orderitem.dart';

class CheckoutDialog {
  static Future<bool> show({
    required BuildContext context,
    required OrderItem orderitem,
    required String placeName,
  }) async {
    String selectedPayment = 'Bar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final paymentButtons = [
            {'name': 'Bar', 'icon': Icons.payments_outlined},
            {'name': 'EC-Karte', 'icon': Icons.credit_card_outlined},
            {'name': 'Gutschein', 'icon': Icons.card_giftcard_outlined},
            {'name': 'Frei', 'icon': Icons.money_off_csred_sharp},
          ];
          final lines = orderitem.lines;
          final total = lines.fold<double>(0, (sum, l) => sum + l.total);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF3A6FFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Kassieren - Tisch: $placeName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: paymentButtons.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.2,
                    ),
                    itemBuilder: (_, index) {
                      final button = paymentButtons[index];
                      final isSelected = selectedPayment == button['name'];
                      return ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            selectedPayment = button['name'] as String;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSelected ? const Color(0xFF3A6FFF) : Colors.white,
                          foregroundColor:
                              isSelected ? Colors.white : const Color(0xFF1A237E),
                          elevation: isSelected ? 2 : 0,
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF3A6FFF)
                                : const Color(0xFFBBCCFF),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(button['icon'] as IconData, size: 18),
                        label: Text(
                          button['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 16, thickness: 1.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total ($selectedPayment)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '€${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3A6FFF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A6FFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Kassieren'),
                onPressed: () {
                  Navigator.of(ctx).pop(true);
                  // TODO: submit order to server
                },
              ),
            ],
          );
        },
      ),
    );

    return confirmed ?? false;
  }
}
