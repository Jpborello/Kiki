class AppSettings {
  String childName;
  String? childPhotoPath;
  String? welcomeAudioPath;
  String? parentPin;

  AppSettings({
    this.childName = 'Kiara Zoe',
    this.childPhotoPath,
    this.welcomeAudioPath,
    this.parentPin,
  });

  Map<String, dynamic> toJson() => {
        'childName': childName,
        'childPhotoPath': childPhotoPath,
        'welcomeAudioPath': welcomeAudioPath,
        'parentPin': parentPin,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      childName: json['childName'] as String? ?? 'Kiara Zoe',
      childPhotoPath: json['childPhotoPath'] as String?,
      welcomeAudioPath: json['welcomeAudioPath'] as String?,
      parentPin: json['parentPin'] as String?,
    );
  }
}
