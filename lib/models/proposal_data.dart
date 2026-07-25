import 'dart:convert';

class ProposalData {
  String title;

  String senderName;
  String senderCompany;
  String senderEmail;
  String senderPhone;

  String clientName;
  String clientCompany;

  String date;
  String overview;
  String scopeOfWork;
  String timeline;
  String pricing;
  String termsAndConditions;

  ProposalData({
    this.title = '',
    this.senderName = '',
    this.senderCompany = '',
    this.senderEmail = '',
    this.senderPhone = '',
    this.clientName = '',
    this.clientCompany = '',
    this.date = '',
    this.overview = '',
    this.scopeOfWork = '',
    this.timeline = '',
    this.pricing = '',
    this.termsAndConditions = '',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'senderName': senderName,
        'senderCompany': senderCompany,
        'senderEmail': senderEmail,
        'senderPhone': senderPhone,
        'clientName': clientName,
        'clientCompany': clientCompany,
        'date': date,
        'overview': overview,
        'scopeOfWork': scopeOfWork,
        'timeline': timeline,
        'pricing': pricing,
        'termsAndConditions': termsAndConditions,
      };

  factory ProposalData.fromJson(Map<String, dynamic> json) => ProposalData(
        title: json['title'] ?? '',
        senderName: json['senderName'] ?? '',
        senderCompany: json['senderCompany'] ?? '',
        senderEmail: json['senderEmail'] ?? '',
        senderPhone: json['senderPhone'] ?? '',
        clientName: json['clientName'] ?? '',
        clientCompany: json['clientCompany'] ?? '',
        date: json['date'] ?? '',
        overview: json['overview'] ?? '',
        scopeOfWork: json['scopeOfWork'] ?? '',
        timeline: json['timeline'] ?? '',
        pricing: json['pricing'] ?? '',
        termsAndConditions: json['termsAndConditions'] ?? '',
      );

  String encode() => jsonEncode(toJson());

  factory ProposalData.decode(String source) => ProposalData.fromJson(jsonDecode(source));
}
