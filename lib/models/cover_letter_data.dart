import 'dart:convert';

class CoverLetterData {
  // Sender
  String fullName;
  String email;
  String phone;
  String address;

  // Recipient
  String recipientName;
  String recipientTitle;
  String companyName;
  String companyAddress;

  String date;
  String jobTitle;
  String salutation;
  String body;
  String closing;

  CoverLetterData({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.recipientName = '',
    this.recipientTitle = '',
    this.companyName = '',
    this.companyAddress = '',
    this.date = '',
    this.jobTitle = '',
    this.salutation = 'Dear Hiring Manager,',
    this.body = '',
    this.closing = 'Sincerely,',
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'recipientName': recipientName,
        'recipientTitle': recipientTitle,
        'companyName': companyName,
        'companyAddress': companyAddress,
        'date': date,
        'jobTitle': jobTitle,
        'salutation': salutation,
        'body': body,
        'closing': closing,
      };

  factory CoverLetterData.fromJson(Map<String, dynamic> json) => CoverLetterData(
        fullName: json['fullName'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        address: json['address'] ?? '',
        recipientName: json['recipientName'] ?? '',
        recipientTitle: json['recipientTitle'] ?? '',
        companyName: json['companyName'] ?? '',
        companyAddress: json['companyAddress'] ?? '',
        date: json['date'] ?? '',
        jobTitle: json['jobTitle'] ?? '',
        salutation: json['salutation'] ?? 'Dear Hiring Manager,',
        body: json['body'] ?? '',
        closing: json['closing'] ?? 'Sincerely,',
      );

  String encode() => jsonEncode(toJson());

  factory CoverLetterData.decode(String source) =>
      CoverLetterData.fromJson(jsonDecode(source));

  /// Weighted completion score shown on the dashboard's document cards.
  double get completionPercent {
    var score = 0.0;
    if (fullName.isNotEmpty) score += 10;
    if (email.isNotEmpty || phone.isNotEmpty) score += 10;
    if (recipientName.isNotEmpty || companyName.isNotEmpty) score += 20;
    if (jobTitle.isNotEmpty) score += 15;
    if (body.trim().length >= 200) {
      score += 45;
    } else if (body.trim().isNotEmpty) {
      score += 20;
    }
    return score.clamp(0, 100);
  }
}
