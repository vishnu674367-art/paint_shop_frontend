import 'slip_downloader_stub.dart'
    if (dart.library.html) 'slip_downloader_web.dart' as impl;

/// Triggers an immediate download of the receipt slip file on supported platforms (Web).
Future<bool> downloadReceiptSlip({
  required String fileName,
  required String htmlContent,
}) {
  return impl.downloadReceiptSlip(
    fileName: fileName,
    htmlContent: htmlContent,
  );
}

/// Builds a clean, printable HTML receipt slip.
String buildReceiptSlipHtml({
  required String shopName,
  required String shopAddress,
  required String shopPhone,
  required String shopGst,
  required String invoiceNo,
  required String date,
  required String customerName,
  required String customerPhone,
  String customerAddress = '',
  String paymentRef = '',
  required String paymentMethod,
  required String paymentStatus,
  required List<Map<String, dynamic>> items,
  required double subtotal,
  required double discount,
  required double taxAmount,
  required double totalAmount,
  required double paidAmount,
  required double balanceAmount,
  required String footerText,
}) {
  String esc(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  final rowsBuffer = StringBuffer();
  for (final it in items) {
    final name = esc(it['product_name']?.toString() ?? 'Item');
    final qty = it['quantity']?.toString() ?? '1';
    final unitPrice = (double.tryParse(it['unit_price']?.toString() ?? '0') ?? 0)
        .toStringAsFixed(2);
    final lineTotal = (double.tryParse(it['line_total']?.toString() ?? '0') ?? 0)
        .toStringAsFixed(2);
    rowsBuffer.writeln('''
      <tr>
        <td class="item-name">$name<div class="item-sub">$qty x &#8377;$unitPrice</div></td>
        <td class="right">&#8377;$lineTotal</td>
      </tr>
    ''');
  }

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Receipt - ${esc(invoiceNo)}</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: #f1f5f9;
      margin: 0;
      padding: 24px;
      color: #0f172a;
    }
    .receipt {
      max-width: 380px;
      margin: 0 auto;
      background: #ffffff;
      border: 1px solid #e2e8f0;
      border-radius: 10px;
      padding: 22px 20px;
      box-shadow: 0 4px 18px rgba(15, 23, 42, 0.06);
    }
    .center { text-align: center; }
    .shop-name { font-size: 18px; font-weight: 800; color: #151b3b; margin: 0 0 4px; }
    .muted { font-size: 12px; color: #64748b; line-height: 1.45; }
    .divider { border-top: 1px dashed #cbd5e1; margin: 14px 0; }
    .meta-row {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      margin-bottom: 5px;
      color: #334155;
    }
    .meta-row strong { color: #0f172a; }
    table { width: 100%; border-collapse: collapse; margin-top: 6px; }
    th {
      text-align: left;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.4px;
      color: #64748b;
      padding-bottom: 6px;
      border-bottom: 1px solid #e2e8f0;
    }
    th.right, td.right { text-align: right; }
    td { padding: 7px 0; font-size: 13px; vertical-align: top; }
    .item-name { font-weight: 600; color: #0f172a; }
    .item-sub { font-size: 11px; color: #64748b; font-weight: 400; margin-top: 2px; }
    .total-row {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      margin-bottom: 5px;
      color: #334155;
    }
    .grand-total {
      display: flex;
      justify-content: space-between;
      font-size: 16px;
      font-weight: 800;
      color: #151b3b;
      margin-top: 8px;
      padding-top: 8px;
      border-top: 1px solid #e2e8f0;
    }
    .badge {
      display: inline-block;
      padding: 2px 8px;
      border-radius: 999px;
      font-size: 11px;
      font-weight: 700;
      background: #dcfce7;
      color: #166534;
    }
    .footer {
      text-align: center;
      font-size: 12px;
      color: #64748b;
      margin-top: 14px;
    }
    @media print {
      body { background: #ffffff; padding: 0; }
      .receipt { box-shadow: none; border: none; max-width: 100%; }
    }
  </style>
</head>
<body>
  <div class="receipt">
    <div class="center">
      <div class="shop-name">${esc(shopName)}</div>
      ${shopAddress.isNotEmpty ? '<div class="muted">${esc(shopAddress)}</div>' : ''}
      ${shopPhone.isNotEmpty ? '<div class="muted">Ph: ${esc(shopPhone)}</div>' : ''}
      ${shopGst.isNotEmpty ? '<div class="muted">GSTIN: ${esc(shopGst)}</div>' : ''}
    </div>

    <div class="divider"></div>

    <div class="meta-row"><span>Invoice No:</span><strong>${esc(invoiceNo)}</strong></div>
    <div class="meta-row"><span>Date:</span><strong>${esc(date)}</strong></div>
    <div class="meta-row"><span>Customer:</span><strong>${esc(customerName)}</strong></div>
    ${customerPhone.isNotEmpty ? '<div class="meta-row"><span>Phone:</span><strong>${esc(customerPhone)}</strong></div>' : ''}
    ${customerAddress.isNotEmpty ? '<div class="meta-row"><span>Address:</span><strong>${esc(customerAddress)}</strong></div>' : ''}
    <div class="meta-row"><span>Payment:</span><strong>${esc(paymentMethod)}</strong></div>
    ${paymentRef.isNotEmpty ? '<div class="meta-row"><span>Ref / Txn No:</span><strong>${esc(paymentRef)}</strong></div>' : ''}
    <div class="meta-row"><span>Status:</span><span class="badge">${esc(paymentStatus)}</span></div>

    <div class="divider"></div>

    <table>
      <thead>
        <tr>
          <th>Item</th>
          <th class="right">Amount</th>
        </tr>
      </thead>
      <tbody>
        ${rowsBuffer.toString()}
      </tbody>
    </table>

    <div class="divider"></div>

    <div class="total-row"><span>Subtotal</span><span>&#8377;${subtotal.toStringAsFixed(2)}</span></div>
    ${discount > 0 ? '<div class="total-row"><span>Discount</span><span>-&#8377;${discount.toStringAsFixed(2)}</span></div>' : ''}
    <div class="total-row"><span>GST / Tax</span><span>&#8377;${taxAmount.toStringAsFixed(2)}</span></div>
    <div class="grand-total"><span>Grand Total</span><span>&#8377;${totalAmount.toStringAsFixed(2)}</span></div>
    <div class="total-row" style="margin-top:6px;"><span>Paid Amount</span><span>&#8377;${paidAmount.toStringAsFixed(2)}</span></div>
    ${balanceAmount > 0 ? '<div class="total-row"><span>Balance Due</span><span>&#8377;${balanceAmount.toStringAsFixed(2)}</span></div>' : ''}

    <div class="divider"></div>
    <div class="footer">${esc(footerText)}</div>
  </div>
</body>
</html>''';
}
