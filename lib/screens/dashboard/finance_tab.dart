import 'package:flutter/material.dart';

class FinanceTab extends StatelessWidget {
  final String clientId;
  final String branchId;
  const FinanceTab({super.key, required this.clientId, required this.branchId});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF3A5068), size: 48),
            SizedBox(height: 12),
            Text('Finance', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Fees · Payroll · Revenue Share', style: TextStyle(color: Color(0xFF556677), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}