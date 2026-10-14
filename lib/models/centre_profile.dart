class CentreProfile {
  final int id;
  final String centreName;
  final String tagline;
  final String phone;
  final String email;
  final String address;
  final String inchargeName;

  CentreProfile({
    this.id = 1,
    required this.centreName,
    required this.tagline,
    required this.phone,
    required this.email,
    required this.address,
    required this.inchargeName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'centre_name': centreName,
      'tagline': tagline,
      'phone': phone,
      'email': email,
      'address': address,
      'incharge_name': inchargeName,
    };
  }

  factory CentreProfile.fromMap(Map<String, dynamic> map) {
    return CentreProfile(
      id: map['id'] as int? ?? 1,
      centreName: map['centre_name'] as String? ?? 'SS Tuition Centre',
      tagline: map['tagline'] as String? ?? 'Inspiring Minds, Shaping Futures',
      phone: map['phone'] as String? ?? '+91 98765 43210',
      email: map['email'] as String? ?? 'sstuitioncentre@gmail.com',
      address: map['address'] as String? ?? 'No. 12, Main Road, Near Bus Stand',
      inchargeName: map['incharge_name'] as String? ?? 'Authorized In-Charge',
    );
  }

  factory CentreProfile.defaultProfile() {
    return CentreProfile(
      id: 1,
      centreName: 'SS Tuition Centre',
      tagline: 'Inspiring Minds, Shaping Futures',
      phone: '+91 98765 43210',
      email: 'sstuitioncentre@gmail.com',
      address: 'No. 12, Main Road, Near Bus Stand',
      inchargeName: 'Authorized In-Charge',
    );
  }
}
