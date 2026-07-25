import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class PersonalInfo {
  String fullName;
  String jobTitle;
  String email;
  String phone;
  String location;
  String summary;
  /// Base64-encoded profile photo (JPEG). Empty if the user hasn't uploaded
  /// one. Stored inline (rather than a file path) so the resume stays a
  /// single self-contained JSON blob in local storage.
  String photoBase64;

  PersonalInfo({
    this.fullName = '',
    this.jobTitle = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.summary = '',
    this.photoBase64 = '',
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'jobTitle': jobTitle,
        'email': email,
        'phone': phone,
        'location': location,
        'summary': summary,
        'photoBase64': photoBase64,
      };

  factory PersonalInfo.fromJson(Map<String, dynamic> json) => PersonalInfo(
        fullName: json['fullName'] ?? '',
        jobTitle: json['jobTitle'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        location: json['location'] ?? '',
        summary: json['summary'] ?? '',
        photoBase64: json['photoBase64'] ?? '',
      );
}

class ExperienceEntry {
  String id;
  String company;
  String role;
  String startDate;
  String endDate;
  String description;

  ExperienceEntry({
    String? id,
    this.company = '',
    this.role = '',
    this.startDate = '',
    this.endDate = '',
    this.description = '',
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'company': company,
        'role': role,
        'startDate': startDate,
        'endDate': endDate,
        'description': description,
      };

  factory ExperienceEntry.fromJson(Map<String, dynamic> json) =>
      ExperienceEntry(
        id: json['id'],
        company: json['company'] ?? '',
        role: json['role'] ?? '',
        startDate: json['startDate'] ?? '',
        endDate: json['endDate'] ?? '',
        description: json['description'] ?? '',
      );
}

class EducationEntry {
  String id;
  String school;
  String degree;
  String startDate;
  String endDate;

  EducationEntry({
    String? id,
    this.school = '',
    this.degree = '',
    this.startDate = '',
    this.endDate = '',
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'school': school,
        'degree': degree,
        'startDate': startDate,
        'endDate': endDate,
      };

  factory EducationEntry.fromJson(Map<String, dynamic> json) =>
      EducationEntry(
        id: json['id'],
        school: json['school'] ?? '',
        degree: json['degree'] ?? '',
        startDate: json['startDate'] ?? '',
        endDate: json['endDate'] ?? '',
      );
}

class ResumeData {
  PersonalInfo personalInfo;
  List<ExperienceEntry> experience;
  List<EducationEntry> education;
  List<String> skills;

  ResumeData({
    PersonalInfo? personalInfo,
    List<ExperienceEntry>? experience,
    List<EducationEntry>? education,
    List<String>? skills,
  })  : personalInfo = personalInfo ?? PersonalInfo(),
        experience = experience ?? [],
        education = education ?? [],
        skills = skills ?? [];

  Map<String, dynamic> toJson() => {
        'personalInfo': personalInfo.toJson(),
        'experience': experience.map((e) => e.toJson()).toList(),
        'education': education.map((e) => e.toJson()).toList(),
        'skills': skills,
      };

  factory ResumeData.fromJson(Map<String, dynamic> json) => ResumeData(
        personalInfo: PersonalInfo.fromJson(json['personalInfo'] ?? {}),
        experience: (json['experience'] as List? ?? [])
            .map((e) => ExperienceEntry.fromJson(e))
            .toList(),
        education: (json['education'] as List? ?? [])
            .map((e) => EducationEntry.fromJson(e))
            .toList(),
        skills: List<String>.from(json['skills'] ?? []),
      );

  String encode() => jsonEncode(toJson());

  factory ResumeData.decode(String source) =>
      ResumeData.fromJson(jsonDecode(source));

  /// Weighted completion score shown on the dashboard's document cards.
  double get completionPercent {
    var score = 0.0;
    if (personalInfo.fullName.isNotEmpty) score += 15;
    if (personalInfo.email.isNotEmpty || personalInfo.phone.isNotEmpty) score += 10;
    if (personalInfo.summary.isNotEmpty) score += 15;
    if (experience.isNotEmpty) score += 25;
    if (education.isNotEmpty) score += 20;
    if (skills.length >= 3) score += 15;
    return score.clamp(0, 100);
  }
}
